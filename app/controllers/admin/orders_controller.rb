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
    end

    def refund
      order = Order.find(params[:id])
      payment = order.payments.where(status: %w[paid partially_refunded]).order(created_at: :desc).first!
      amount_cents = refund_amount_cents(payment)

      Payments::Refund.new(
        payment: payment,
        amount_cents: amount_cents,
        idempotency_key: params.require(:idempotency_key)
      ).call
      Notification.create!(
        recipient: order.seller_order.seller,
        kind: :order_refunded,
        title: order.refunded? ? "Reembolso total" : "Reembolso parcial",
        body: "O pedido ##{order.id} recebeu um reembolso#{" total" if order.refunded?}.",
        url: seller_order_path(order)
      )

      redirect_to admin_order_path(order), notice: "Reembolso solicitado com sucesso."
    rescue Payments::Refund::InvalidRefund, ActiveRecord::RecordNotFound => e
      redirect_to admin_order_path(params[:id]), alert: e.message
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
