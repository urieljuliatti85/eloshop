require "csv"

module Admin
  class FinancialsController < BaseController
    SETTLED_ORDER_STATUSES = %w[confirmed partially_refunded refunded].freeze
    IN_PROGRESS_PAYMENT_STATUSES = %w[processing pending authorized].freeze
    SUCCESSFUL_PAYMENT_STATUSES = %w[paid partially_refunded refunded].freeze
    RECONCILIATION_LIMIT = 100
    RELEASE_DATE_LOOKUP_LIMIT = 50
    RELEASE_DATES_CACHE_KEY = "admin/mercado_pago_release_dates/v1"
    RECONCILIATION_CACHE_TTL = 24.hours

    def index
      @filters = financial_filters
      @sellers = Seller.order(:name).pluck(:name, :id)
      load_integration_status
      load_financial_summary
      load_reconciliation
      load_seller_pendencies
    end

    def refresh_reconciliation
      report_client = Marketplace::MercadoPagoSalesReport.new
      unless report_client.configured?
        redirect_to admin_financials_path, alert: "Configure o token de produção do relatório Mercado Pago antes de atualizar."
        return
      end

      report = report_client.refresh!
      refresh_release_dates(report)
      redirect_to admin_financials_path, notice: "Conciliação atualizada com #{report.entries.size} registros oficiais."
    rescue Marketplace::MercadoPagoSalesReport::ReportUnavailable,
      Marketplace::MercadoPagoSalesReport::RequestFailed => e
      redirect_to admin_financials_path, alert: e.message
    end

    def export
      @filters = financial_filters
      @sellers = Seller.order(:name).pluck(:name, :id)
      load_integration_status
      load_financial_summary
      load_reconciliation

      csv = CSV.generate(headers: true) do |rows|
        rows << [
          "Venda",
          "Artesão",
          "Valor",
          "Comissão",
          "Tarifa MP",
          "Líquido artesão",
          "Data da venda",
          "Data de liberação",
          "Status de liberação",
          "Fonte"
        ]

        @reconciliation_rows.each do |row|
          rows << [
            row.fetch(:sale_reference),
            row.fetch(:artisan),
            format_csv_money(row.fetch(:gross_cents)),
            format_csv_money(row.fetch(:commission_cents)),
            format_csv_money(row.fetch(:processor_fee_cents)),
            format_csv_money(row.fetch(:net_cents)),
            row.fetch(:sold_at) ? row.fetch(:sold_at).to_date.iso8601 : "",
            row.fetch(:release_at) ? row.fetch(:release_at).to_date.iso8601 : "",
            row.fetch(:release_at).present? ? "Liberado" : "Pendente",
            row.fetch(:official) ? "Mercado Pago" : "Somente EloShop"
          ]
        end
      end

      send_data csv, filename: "conciliacao-financeira-#{Date.current.iso8601}.csv", type: "text/csv"
    end

    private

    def load_integration_status
      oauth = Marketplace::MercadoPagoOauth.new

      @gateway_active = ENV["PAYMENT_GATEWAY"] == "mercado_pago"
      @oauth_configured = oauth.configured?
      @sandbox = oauth.sandbox?
      @webhook_configured = ENV["MERCADO_PAGO_WEBHOOK_SECRET"].present?
      @integration_ready = @gateway_active && @oauth_configured && @webhook_configured
      @last_webhook_at = PaymentEvent.joins(:payment)
        .where(payments: { gateway: "mercado_pago" })
        .maximum(:processed_at)
    end

    def load_financial_summary
      settled_orders = SellerOrder.where(status: SETTLED_ORDER_STATUSES)

      @net_sales_cents = settled_orders.sum("total_cents - refunded_amount_cents")
      @platform_fee_cents = settled_orders.sum("platform_fee_cents - platform_fee_refunded_cents")
      @seller_net_cents = settled_orders.sum(
        "seller_amount_cents - refunded_amount_cents + platform_fee_refunded_cents"
      )

      mercado_pago_payments = Payment.where(gateway: "mercado_pago")
      @payment_attempts_count = mercado_pago_payments.count
      @payments_in_progress_count = mercado_pago_payments.where(status: IN_PROGRESS_PAYMENT_STATUSES).count
      @successful_payments_count = mercado_pago_payments.where(status: SUCCESSFUL_PAYMENT_STATUSES).count
      @failed_payments_count = mercado_pago_payments.failed.count
    end

    def load_reconciliation
      report_client = Marketplace::MercadoPagoSalesReport.new
      @sales_report_configured = report_client.configured?
      @official_report = report_client.cached
      @reconciliation_rows = apply_filters(reconciliation_rows(@official_report, cached_release_dates))
      @seller_summary = summarize_by_seller(@reconciliation_rows)
    end

    def financial_filters
      params.permit(:seller_id, :date_from, :date_to, :release_status).to_h.symbolize_keys
    end

    def apply_filters(rows)
      seller_id = @filters[:seller_id].presence
      date_from = parse_date(@filters[:date_from])
      date_to = parse_date(@filters[:date_to])
      release_status = @filters[:release_status].presence || "all"

      rows.select do |row|
        if seller_id.present? && row.fetch(:seller_id).to_s != seller_id.to_s
          next false
        end

        sold_at = row.fetch(:sold_at)
        if sold_at.present?
          sold_on = sold_at.to_date
          next false if date_from.present? && sold_on < date_from
          next false if date_to.present? && sold_on > date_to
        elsif date_from.present? || date_to.present?
          next false
        end

        if release_status != "all"
          is_released = row.fetch(:release_at).present?
          next false if release_status == "released" && !is_released
          next false if release_status == "pending" && is_released
        end

        true
      end
    end

    def summarize_by_seller(rows)
      seller_totals = rows.group_by { |row| row.fetch(:seller_id) || row.fetch(:artisan) }

      seller_totals.map do |seller_key, seller_rows|
        seller = Seller.find_by(id: seller_key) || Seller.find_by(name: seller_key)
        {
          seller: seller,
          name: seller&.name || seller_rows.first.fetch(:artisan),
          gross_cents: seller_rows.sum { |row| row.fetch(:gross_cents).to_i },
          commission_cents: seller_rows.sum { |row| row.fetch(:commission_cents).to_i },
          processor_fee_cents: seller_rows.sum { |row| row.fetch(:processor_fee_cents).to_i },
          net_cents: seller_rows.sum { |row| row.fetch(:net_cents).to_i },
          released_count: seller_rows.count { |row| row.fetch(:release_at).present? },
          pending_count: seller_rows.count { |row| row.fetch(:release_at).blank? }
        }
      end.sort_by { |entry| entry[:net_cents] }.reverse
    end

    def reconciliation_rows(report, release_dates)
      local_payments = Payment.includes(order: { seller_orders: :seller })
        .where(gateway: "mercado_pago", status: SUCCESSFUL_PAYMENT_STATUSES)
        .where.not(external_id: [ nil, "" ])
        .order(created_at: :desc)
        .limit(RECONCILIATION_LIMIT)
        .to_a

      official_entries = report&.entries.to_a
      official_by_payment = official_entries.index_by { |entry| entry.payment_id.to_s }
      official_by_order = official_entries.index_by { |entry| entry.external_reference.to_s }
      matched_entries = []

      rows = local_payments.map do |payment|
        entry = official_by_payment[payment.external_id.to_s] || official_by_order[payment.order_id.to_s]
        matched_entries << entry if entry
        reconciliation_row(payment: payment, entry: entry, release_dates: release_dates)
      end

      (official_entries - matched_entries).each do |entry|
        rows << reconciliation_row(payment: nil, entry: entry, release_dates: release_dates)
      end

      rows.sort_by { |row| row.fetch(:sold_at) || Time.at(0) }.reverse.first(RECONCILIATION_LIMIT)
    end

    def reconciliation_row(payment:, entry:, release_dates:)
      seller_order = payment&.order&.seller_order
      gross_cents = entry&.transaction_amount_cents || local_gross_cents(payment)
      commission_cents = entry&.marketplace_fee_cents || local_commission_cents(payment)
      processor_fee_cents = entry&.mercado_pago_fee_cents || payment&.processor_fee_cents
      seller_id = seller_order&.seller_id || Seller.find_by(name: entry&.collector_name)&.id

      {
        payment: payment,
        seller_id: seller_id,
        sale_reference: payment&.order_id || entry&.external_reference || entry&.payment_id,
        artisan: seller_order&.seller&.name || entry&.collector_name || "Não identificado",
        gross_cents: gross_cents,
        commission_cents: commission_cents,
        processor_fee_cents: processor_fee_cents,
        net_cents: entry&.net_received_amount_cents || calculated_net(gross_cents, commission_cents, processor_fee_cents),
        sold_at: entry&.approved_at || payment&.updated_at,
        release_at: parse_cached_time(release_dates[payment&.external_id.to_s]),
        official: entry.present?
      }
    end

    def local_gross_cents(payment)
      payment && payment.amount_cents - payment.refunded_amount_cents
    end

    def local_commission_cents(payment)
      payment && payment.application_fee_cents - payment.application_fee_refunded_cents
    end

    def calculated_net(gross_cents, commission_cents, processor_fee_cents)
      return if gross_cents.nil? || commission_cents.nil? || processor_fee_cents.nil?

      gross_cents - commission_cents - processor_fee_cents
    end

    def refresh_release_dates(report)
      payment_ids = report.entries.filter_map(&:payment_id).uniq.first(RELEASE_DATE_LOOKUP_LIMIT)
      payments = Payment.where(gateway: "mercado_pago", external_id: payment_ids).index_by(&:external_id)
      release_dates = cached_release_dates
      gateway = Gateways::MercadoPago.new

      payments.each_value do |payment|
        details = gateway.reconciliation_details(external_id: payment.external_id)
        release_dates[payment.external_id] = details[:money_release_date]&.iso8601
      rescue Gateways::MercadoPago::ConfigurationError, Gateways::MercadoPago::RequestFailed => e
        Rails.event.notify(
          "admin.mercado_pago_reconciliation.release_lookup_failed",
          payment_id: payment.id,
          error_class: e.class.name
        )
      end

      Rails.cache.write(RELEASE_DATES_CACHE_KEY, release_dates, expires_in: RECONCILIATION_CACHE_TTL)
    end

    def cached_release_dates
      Rails.cache.read(RELEASE_DATES_CACHE_KEY).presence || {}
    end

    def parse_cached_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError, TypeError
      nil
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error, TypeError, ArgumentError
      nil
    end

    def format_csv_money(amount)
      return "" if amount.nil?

      view_context.format_price(amount)
    end

    def load_seller_pendencies
      @seller_pendencies = Seller.order(:name).filter_map do |seller|
        issues = seller_financial_issues(seller)
        { seller: seller, issues: issues } if issues.any?
      end
    end

    def seller_financial_issues(seller)
      unless seller.mercado_pago_connected?
        return [ "Conectar a conta Mercado Pago." ]
      end

      issues = []
      if seller.mercado_pago_test_account.nil?
        issues << "O tipo da conta Mercado Pago não pôde ser confirmado."
      elsif !@sandbox && !seller.mercado_pago_real_account?
        issues << "Reconectar uma conta real de produção."
      end

      unless seller.mercado_pago_card_payments_available?
        issues << "Reconectar para habilitar cartão; PIX continua disponível."
      end

      issues << "Aguardando aprovação da EloShop." if seller.pending?
      issues << "Cadastro suspenso na EloShop." if seller.suspended?
      issues
    end
  end
end
