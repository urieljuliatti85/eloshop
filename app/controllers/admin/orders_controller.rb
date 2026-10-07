module Admin
  class OrdersController < BaseController
    SORTABLE_COLUMNS = {
      "id" => "orders.id",
      "customer" => "customers.name",
      "status" => "orders.status",
      "total" => "orders.total_cents",
      "date" => "orders.created_at"
    }.freeze

    def index
      @order_counts = Order.group(:status).count

      # `joins(:customer)` só para permitir ordenar/filtrar por
      # `customers.name` — `payments`/`seller_orders` continuam em `preload`
      # para não repetir o LEFT JOIN e inflar o custo estimado do plano
      # (CLAUDE.md, Fase 17).
      orders = Order.joins(:customer).preload(:customer, :payments, seller_orders: [ { seller: :users }, :shipment ])
      orders = apply_filters(orders)
      orders = orders.order(sort_clause)

      @sellers = Seller.order(:name)
      @orders = paginate(orders)
    end

    def show
      @order = Order.includes(:customer, :coupon, :payments, seller_orders: %i[seller shipment],
        order_items: { product: :main_image_attachment }).find(params[:id])
      @order_events = @order.order_events.chronological
      @release_date = release_date_for(@order.payments.max_by(&:created_at))
    end

    def refund
      order = Order.find(params[:id])
      payment = order.payments.where(status: %w[paid partially_refunded]).order(created_at: :desc).first!
      amount_cents = refund_amount_cents(payment)

      refund = Payments::Refund.new(
        payment: payment,
        amount_cents: amount_cents,
        idempotency_key: params.require(:idempotency_key)
      ).call

      if refund.approved?
        Notification.create!(
          recipient: order.seller_order.seller,
          kind: :order_refunded,
          title: order.refunded? ? "Reembolso total" : "Reembolso parcial",
          body: "O pedido ##{order.id} recebeu um reembolso#{" total" if order.refunded?}.",
          url: seller_order_path(order)
        )
        redirect_to admin_order_path(order), notice: "Reembolso solicitado com sucesso."
      elsif refund.processing?
        redirect_to admin_order_path(order), notice: "O Mercado Pago ainda está processando o reembolso. Confira o pedido em alguns minutos antes de tentar de novo."
      else
        redirect_to admin_order_path(order), alert: "O Mercado Pago não aprovou o reembolso. Nada foi devolvido."
      end
    rescue Payments::Refund::InvalidRefund, ActiveRecord::RecordNotFound => e
      redirect_to admin_order_path(params[:id]), alert: e.message
    rescue Gateways::MercadoPago::InsufficientFunds => e
      redirect_to admin_order_path(params[:id]), alert: insufficient_funds_message(e.release_date)
    rescue Gateways::MercadoPago::RequestRejected => e
      redirect_to admin_order_path(params[:id]), alert: "O Mercado Pago recusou o reembolso e nada foi devolvido (#{e.message})."
    rescue Gateways::MercadoPago::RequestFailed, Gateways::MercadoPago::ConfigurationError => e
      redirect_to admin_order_path(params[:id]), alert: "Não foi possível confirmar o reembolso com o Mercado Pago (#{e.message}). Confira o pagamento lá antes de tentar de novo."
    end

    def cancel
      order = Order.find(params[:id])
      Orders::Cancel.new.call(order)
      Notification.create!(
        recipient: order.seller_order.seller,
        kind: :order_cancelled,
        title: "Pedido cancelado",
        body: "O pedido ##{order.id} foi cancelado.",
        url: seller_order_path(order)
      )

      redirect_to admin_order_path(order), notice: "Pedido cancelado e estoque devolvido."
    rescue Orders::Cancel::InvalidCancellation => e
      redirect_to admin_order_path(order), alert: e.message
    end

    private

    # Previsão do Mercado Pago de quando o dinheiro fica disponível para um
    # reembolso. É só informação: se a consulta falhar, a página abre sem ela,
    # e o resultado fica em cache para o admin abrir o pedido sem esperar o
    # provedor a cada visita.
    def release_date_for(payment)
      return unless payment&.gateway == "mercado_pago" && (payment.paid? || payment.partially_refunded?)

      Rails.cache.fetch([ "mercado_pago_release_date", payment.id ], expires_in: 1.hour, skip_nil: true) do
        Gateways::MercadoPago.new.reconciliation_details(external_id: payment.external_id)[:money_release_date]
      end
    rescue Gateways::MercadoPago::ConfigurationError, Gateways::MercadoPago::RequestFailed => e
      Rails.event.notify(
        "admin.order.release_date_lookup_failed",
        payment_id: payment.id,
        error_class: e.class.name
      )
      nil
    end

    def insufficient_funds_message(release_date)
      base = "O Mercado Pago não devolveu o dinheiro porque a conta do artesão ainda não tem saldo disponível. Nada foi devolvido."

      if release_date&.future?
        "#{base} A liberação está prevista para #{I18n.l(release_date.in_time_zone.to_date)}; tente o reembolso de novo depois dessa data."
      else
        "#{base} Confira a data de liberação no painel do Mercado Pago e tente de novo depois dela."
      end
    end

    def apply_filters(orders)
      orders = orders.where(id: params[:order_id]) if params[:order_id].present?
      orders = orders.where("customers.name ILIKE :term OR customers.email ILIKE :term", term: "%#{params[:customer]}%") if params[:customer].present?
      orders = orders.where(created_at: filter_date.all_day) if filter_date
      orders = orders.where(id: SellerOrder.where(seller_id: params[:seller_id]).select(:order_id)) if params[:seller_id].present?
      orders = apply_payment_filter(orders)
      orders
    end

    # Filtra por subquery de ids (em vez de `joins(:payments).distinct`) para
    # não colidir com `ORDER BY customers.name`: Postgres exige que colunas
    # de `ORDER BY` apareçam no SELECT quando há `SELECT DISTINCT`, e aqui a
    # ordenação pode vir de uma tabela fora do JOIN de pagamento.
    def apply_payment_filter(orders)
      status = params[:payment_status]
      return orders if status.blank?

      if status == "not_started"
        orders.where.missing(:payments)
      else
        orders.where(id: Payment.where(status: status).select(:order_id))
      end
    end

    def filter_date
      Date.strptime(params[:date], "%d/%m/%Y")
    rescue ArgumentError, TypeError
      nil
    end

    def sort_clause
      column = SORTABLE_COLUMNS.fetch(params[:sort], "orders.created_at")
      direction = params[:direction] == "asc" ? "asc" : "desc"
      "#{column} #{direction}, orders.id #{direction}"
    end

    def refund_amount_cents(payment)
      value = params[:amount].to_s.strip
      return payment.remaining_refundable_cents if value.blank?

      (BigDecimal(value.tr(",", ".")) * 100).round.to_i
    rescue ArgumentError
      0
    end
  end
end
