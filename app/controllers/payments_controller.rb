class PaymentsController < StorefrontController
  before_action :set_order

  def new
    @payment = Payments::Authorize.new(order: @order).call
    @webhook_secret = Gateways::FakeGateway::WEBHOOK_SECRET
  end

  private

  def set_order
    @order = Current.customer.orders.find(params[:order_id])
  end
end
