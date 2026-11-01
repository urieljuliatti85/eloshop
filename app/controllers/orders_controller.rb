class OrdersController < StorefrontController
  before_action :require_sales_open, only: %i[new create]
  before_action :ensure_cart_not_empty, only: :new

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }
  # Por cliente, além do IP: ver o comentário em `PaymentsController`.
  rate_limit to: 5, within: 30.minutes, only: :create, by: -> { Current.customer.id }, name: "per-customer",
    with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def index
    @orders = Current.customer.orders.includes(:order_items).order(created_at: :desc)
  end

  def new
    @cart = Current.cart
    @addresses = Current.customer.addresses
    @shipping_quotes = @addresses.index_with { |address| shipping_quotes_for(address) }
    @selected_address = @addresses.find { |address| @shipping_quotes[address].present? }
    @shipping = @shipping_quotes[@selected_address]&.first
    @shipping_cents = @shipping&.shipping_cents
    checkout_started = session[:checkout_idempotency_key].blank?
    session[:checkout_idempotency_key] ||= SecureRandom.hex(20)
    Analytics::Funnel.track("checkout_started") if checkout_started
  end

  def create
    address = Current.customer.addresses.find(params[:address_id])
    idempotency_key = session[:checkout_idempotency_key] ||= SecureRandom.hex(20)

    order = Checkout::CreateOrder.new(
      cart: Current.cart,
      customer: Current.customer,
      address: address,
      idempotency_key: idempotency_key,
      shipping_quote_id: params[:shipping_quote_id].presence
    ).call

    session.delete(:checkout_idempotency_key)
    redirect_to new_order_payment_path(order), notice: "Pedido \##{order.id} criado. Finalize o pagamento para confirmá-lo."
  rescue Checkout::CreateOrder::Failed => e
    redirect_to cart_path, alert: e.message
  rescue Shipping::Calculator::Unavailable => e
    redirect_to new_order_path, alert: e.message
  end

  def show
    @order = Current.customer.orders.find(params[:id])
    @seller_order = @order.seller_order
  end

  def cancel
    order = Current.customer.orders.find(params[:id])
    Orders::Cancel.new.call(order)

    redirect_to order_path(order), notice: "Pedido cancelado."
  rescue Orders::Cancel::InvalidCancellation => e
    redirect_to order_path(order), alert: e.message
  end

  def deliver
    order = Current.customer.orders.find(params[:id])
    shipment = order.seller_order.shipment
    raise ActiveRecord::RecordNotFound unless shipment

    if shipment.report_delivered_by_customer!
      NotifySellerOfDeliveryJob.perform_later(order.seller_order)
      Notification.create!(
        recipient: order.seller_order.seller,
        kind: :delivery_reported,
        title: shipment.local_pickup? ? "Cliente retirou o pedido" : "Cliente recebeu o pedido",
        body: "O cliente avisou que #{shipment.local_pickup? ? 'retirou' : 'recebeu'} o pedido ##{order.id}. Confirme a entrega no painel.",
        url: seller_order_path(order)
      )
    end

    message = shipment.local_pickup? ? "Retirada confirmada." : "Recebimento confirmado."
    redirect_to order_path(order), notice: message
  rescue Shipment::InvalidStatusTransition => e
    redirect_to order_path(params[:id]), alert: e.message
  end

  private

  # O checkout também é bloqueado, então voltar ao Referer, como no resto da
  # loja, viraria loop: o "Finalizar pedido" de uma tela aberta antes de as
  # vendas fecharem volta para /orders/new, que volta para /orders/new...
  def require_sales_open
    redirect_to cart_path, alert: SALES_CLOSED_ALERT unless PlatformSetting.sales_open?
  end

  def ensure_cart_not_empty
    redirect_to cart_path, alert: "Seu carrinho está vazio." if Current.cart.cart_items.empty?
  end

  def shipping_quotes_for(address)
    Shipping::Calculator.new(cart: @cart, address: address).quotes
  rescue Shipping::Calculator::Unavailable
    nil
  end
end
