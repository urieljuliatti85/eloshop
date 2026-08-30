class OrdersController < StorefrontController
  before_action :ensure_cart_not_empty, only: :new

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def new
    @cart = Current.cart
    @addresses = Current.customer.addresses
    @shipping = Shipping::Calculator.new(cart: @cart, address: @addresses.first).call if @addresses.any?
    @shipping_cents = @shipping&.shipping_cents
    session[:checkout_idempotency_key] ||= SecureRandom.hex(20)
  end

  def create
    address = Current.customer.addresses.find(params[:address_id])
    idempotency_key = session[:checkout_idempotency_key] ||= SecureRandom.hex(20)

    order = Checkout::CreateOrder.new(
      cart: Current.cart,
      customer: Current.customer,
      address: address,
      idempotency_key: idempotency_key
    ).call

    session.delete(:checkout_idempotency_key)
    redirect_to order_path(order), notice: "Pedido \##{order.id} criado com sucesso."
  rescue Checkout::CreateOrder::Failed => e
    redirect_to cart_path, alert: e.message
  rescue Shipping::Calculator::Unavailable => e
    redirect_to new_order_path, alert: e.message
  end

  def show
    @order = Current.customer.orders.find(params[:id])
  end

  private

  def ensure_cart_not_empty
    redirect_to cart_path, alert: "Seu carrinho está vazio." if Current.cart.cart_items.empty?
  end
end
