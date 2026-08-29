class OrdersController < StorefrontController
  before_action :ensure_cart_not_empty, only: :new

  def new
    @cart = Current.cart
    @addresses = Current.customer.addresses
    @shipping_cents = Checkout::CreateOrder::SHIPPING_CENTS
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
    redirect_to root_path, notice: "Pedido \##{order.id} criado com sucesso."
  rescue Checkout::CreateOrder::Failed => e
    redirect_to cart_path, alert: e.message
  end

  private

  def ensure_cart_not_empty
    redirect_to cart_path, alert: "Seu carrinho está vazio." if Current.cart.cart_items.empty?
  end
end
