module Admin
  class OrdersController < BaseController
    def index
      @orders = Order.includes(:customer, :payments, seller_orders: { seller: :users }).order(created_at: :desc)
      @order_counts = Order.group(:status).count
    end

    def show
      @order = Order.includes(:customer, :coupon, :payments, seller_orders: %i[seller shipment],
        order_items: { product: :main_image_attachment }).find(params[:id])
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

    def refund_amount_cents(payment)
      value = params[:amount].to_s.strip
      return payment.remaining_refundable_cents if value.blank?

      (BigDecimal(value.tr(",", ".")) * 100).round.to_i
    rescue ArgumentError
      0
    end
  end
end
