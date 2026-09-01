module Admin
  class OrdersController < BaseController
    def index
      @orders = Order.includes(:customer, :payments).order(created_at: :desc)
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

      redirect_to admin_order_path(order), notice: "Reembolso solicitado com sucesso."
    rescue Payments::Refund::InvalidRefund, ActiveRecord::RecordNotFound => e
      redirect_to admin_order_path(params[:id]), alert: e.message
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
