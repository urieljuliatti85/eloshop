class PaymentsController < StorefrontController
  before_action :set_order

  # Mostra a tela de pagamento sem criar/autorizar nada. Um pedido sem
  # nenhuma tentativa ainda oferece a escolha do meio de pagamento; um pedido
  # com uma tentativa em andamento (PIX pendente, cartão aprovado/recusado)
  # mostra o estado atual — reautorizar aqui reintroduziria o antigo
  # comportamento de "todo GET autoriza", que quebra para cartão (o token só
  # existe depois do Brick, não antes de renderizar a página).
  def new
    @payment = @order.payments.order(:created_at).last
    @gateway = Gateways.build
    @simulated_gateway = @gateway.is_a?(Gateways::FakeGateway)
    @webhook_secret = Gateways::FakeGateway::WEBHOOK_SECRET if @simulated_gateway
  end

  # Autoriza a tentativa escolhida pelo cliente. PIX não precisa de dado
  # adicional (o formulário de escolha já basta); cartão exige o token gerado
  # pelo Card Payment Brick no navegador antes de chegar aqui.
  def create
    payment_method = params[:payment_method]

    @payment = Payments::Authorize.new(
      order: @order,
      gateway: Gateways.build,
      payment_method: payment_method,
      card_token: params[:card_token],
      installments: (params[:installments].presence || 1).to_i
    ).call

    redirect_to new_order_payment_path(@order)
  rescue Gateways::UnknownGateway, Gateways::SimulatedGatewayInProduction,
    Gateways::MercadoPago::ConfigurationError, Gateways::MercadoPago::RequestFailed,
    Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
    # Permanente: foi este evento que identificou a causa da falha de PIX no
    # sandbox (2026-09-08). Loga só classe e mensagem da exceção — que agora
    # carrega o código de erro do gateway —, nunca dados do pedido ou
    # credenciais. A tentativa já foi marcada `failed` por `Payments::Authorize`,
    # então a tela do pedido oferece "Tentar novamente" em vez de prometer uma
    # cobrança que não vem.
    Rails.event.notify("payment.authorize_failed", error_class: e.class.name, error_message: e.message)
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
