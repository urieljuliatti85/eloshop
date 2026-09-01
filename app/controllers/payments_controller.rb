class PaymentsController < StorefrontController
  before_action :set_order

  def new
    gateway = Gateways.build
    @payment = Payments::Authorize.new(order: @order, gateway: gateway).call
    @simulated_gateway = gateway.is_a?(Gateways::FakeGateway)
    @webhook_secret = Gateways::FakeGateway::WEBHOOK_SECRET if @simulated_gateway
  rescue Gateways::UnknownGateway, Gateways::SimulatedGatewayInProduction,
    Gateways::MercadoPago::ConfigurationError, Gateways::MercadoPago::RequestFailed,
    Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    redirect_to order_path(@order), alert: "O pedido foi salvo, mas o pagamento está temporariamente indisponível. Tente novamente em alguns instantes."
  end

  def status
    @payment = @order.payments.order(:created_at).last!
    render partial: "payment", locals: { payment: @payment, order: @order, simulated_gateway: false, webhook_secret: nil }
  end

  private

  def set_order
    @order = Current.customer.orders.find(params[:order_id])
  end
end
