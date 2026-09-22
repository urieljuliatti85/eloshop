module Admin
  class FinancialsController < BaseController
    SETTLED_ORDER_STATUSES = %w[confirmed partially_refunded refunded].freeze
    IN_PROGRESS_PAYMENT_STATUSES = %w[processing pending authorized].freeze
    SUCCESSFUL_PAYMENT_STATUSES = %w[paid partially_refunded refunded].freeze

    def index
      load_integration_status
      load_financial_summary
      load_seller_pendencies
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
