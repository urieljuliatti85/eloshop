# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:customer) { Customer.create!(name: "Cliente checkout", email: "checkout@example.com", password: "password123") }
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso checkout", sku: "CHK-001", price_cents: 10_000, stock_quantity: 3, currency: "BRL", status: :active) }

  def sign_in_customer
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  def add_to_cart(quantity: 1)
    post cart_items_path, params: { product_id: product.id, quantity: quantity }
  end

  describe "GET /orders" do
    it "redirects unauthenticated visitors to customer login" do
      get orders_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "lists only the authenticated customer's orders" do
      own_order = create_order_for(customer, idempotency_key: "own-order")
      other_customer = Customer.create!(name: "Outro", email: "other-list@example.com", password: "password123")
      other_order = create_order_for(other_customer, idempotency_key: "other-order")
      sign_in_customer

      get orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pedido ##{own_order.id}")
      expect(response.body).not_to include("Pedido ##{other_order.id}")
    end

    it "shows an empty state" do
      sign_in_customer

      get orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Você ainda não fez nenhum pedido")
    end
  end

  describe "GET /orders/new" do
    it "redirects unauthenticated visitors to customer login" do
      add_to_cart

      get new_order_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "redirects to cart when the cart is empty" do
      sign_in_customer

      get new_order_path

      expect(response).to redirect_to(cart_path)
    end

    it "shows the checkout summary" do
      sign_in_customer
      add_to_cart
      customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      get new_order_path

      expect(response).to have_http_status(:ok)
    end

    it "shows the seller fixed delivery and free pickup options" do
      product.update!(
        fixed_shipping_cents: 2000,
        fixed_shipping_estimated_days: 8,
        local_pickup_enabled: true
      )
      sign_in_customer
      add_to_cart
      customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      get new_order_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ateliê · Entrega padrão")
      expect(response.body).to include("Até 8 dias úteis · R$ 20,00")
      expect(response.body).to include("Ateliê · Retirada no ateliê")
      expect(response.body).to include("Retirada combinada com o ateliê · R$ 0,00")
    end
  end

  describe "POST /orders" do
    it "creates the order and redirects directly to payment" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      expect do
        post orders_path, params: { address_id: address.id }
      end.to change(Order, :count).by(1)

      order = Order.last
      expect(response).to redirect_to(new_order_payment_path(order))
      expect(order.customer).to eq(customer)
    end

    it "empties the cart after creating the order" do
      sign_in_customer
      add_to_cart
      cart_id = CartItem.last.cart_id
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      post orders_path, params: { address_id: address.id }

      expect(Cart.find(cart_id).cart_items).to be_empty
    end

    # O formulário devolve o identificador da opção, nunca o preço: uma opção
    # forjada não pode virar um frete mais barato.
    it "rejects a shipping option that was never offered" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      expect do
        post orders_path, params: { address_id: address.id, shipping_quote_id: "frete-de-graca" }
      end.not_to change(Order, :count)

      expect(response).to redirect_to(new_order_path)
    end

    it "creates a free local-pickup shipment when the customer chooses it" do
      product.update!(local_pickup_enabled: true)
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      pickup_id = Shipping::Quote.new(
        carrier: "Ateliê",
        service: Shipping::Quote::LOCAL_PICKUP_SERVICE,
        shipping_cents: 0,
        estimated_days: 0
      ).id

      post orders_path, params: { address_id: address.id, shipping_quote_id: pickup_id }

      shipment = Order.last.seller_orders.sole.shipment
      expect(response).to redirect_to(new_order_payment_path(Order.last))
      expect(shipment).to be_local_pickup
      expect(shipment.shipping_cents).to be_zero
    end

    it "rejects an address belonging to another customer" do
      sign_in_customer
      add_to_cart
      other_customer = Customer.create!(name: "Outro", email: "other-checkout@example.com", password: "password123")
      other_address = other_customer.addresses.create!(street: "Rua Alheia", number: "2", neighborhood: "Bairro", city: "Rio", state: "RJ", zip_code: "02000-000")

      expect do
        post orders_path, params: { address_id: other_address.id }
      end.not_to change(Order, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not create an order when stock became insufficient" do
      sign_in_customer
      add_to_cart(quantity: 1)
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      product.update!(stock_quantity: 0)

      expect do
        post orders_path, params: { address_id: address.id }
      end.not_to change(Order, :count)

      expect(response).to redirect_to(cart_path)
    end

    it "rate limits repeated checkout attempts" do
      sign_in_customer

      10.times { post orders_path, params: { address_id: 0 } }

      post orders_path, params: { address_id: 0 }

      follow_redirect!
      expect(response.body).to include("Muitas tentativas")
    end
  end

  describe "GET /orders/:id" do
    it "shows the customer's own order" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last

      get order_path(order)

      expect(response).to have_http_status(:ok)
    end

    # Mesmo componente de linha do tempo do painel do vendedor
    # (ApplicationHelper#seller_order_timeline_steps) — o cliente acompanha o
    # próprio pedido com as mesmas 4 etapas.
    it "shows the fulfillment timeline for the order's seller order" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last

      get order_path(order)

      expect(response.body).to include("Da confirmação à entrega")
      expect(response.body).to include("Pedido recebido")
      expect(response.body).to include("Em preparação")
      expect(response.body).to include("Enviado")
      expect(response.body).to include("Entregue")
    end

    it "does not show another customer's order" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last

      other_customer = Customer.create!(name: "Outro pedido", email: "other-order@example.com", password: "password123")
      delete customer_session_path
      post customer_session_path, params: { email: other_customer.email, password: "password123" }

      get order_path(order)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /orders/:id/cancel" do
    it "cancels the customer's own pending order and restores stock" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last

      post cancel_order_path(order)

      expect(response).to redirect_to(order_path(order))
      expect(order.reload.cancelled?).to be(true)
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "does not cancel an order with an authorized payment" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last
      order.payments.create!(gateway: "fake", external_id: "fake-cancel-own", status: :paid, amount_cents: order.total_cents, application_fee_cents: 0)

      post cancel_order_path(order)

      expect(response).to redirect_to(order_path(order))
      expect(order.reload.pending?).to be(true)
    end

    it "does not allow cancelling another customer's order" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last

      other_customer = Customer.create!(name: "Outro cancelamento", email: "other-cancel@example.com", password: "password123")
      delete customer_session_path
      post customer_session_path, params: { email: other_customer.email, password: "password123" }

      post cancel_order_path(order)

      expect(response).to have_http_status(:not_found)
      expect(order.reload.pending?).to be(true)
    end
  end

  describe "PATCH /orders/:id/deliver" do
    it "lets the customer confirm receipt of a shipped order and notifies the seller" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last
      order.confirm!
      shipment = create_shipment_for(order)
      shipment.mark_shipped!

      expect { patch deliver_order_path(order) }.to have_enqueued_job(NotifySellerOfDeliveryJob).with(order.seller_order)

      expect(response).to redirect_to(order_path(order))
      expect(shipment.reload).to be_delivered
      expect(shipment.delivered_at).to be_present
    end

    it "does not advance an order whose shipment has not been marked as shipped yet" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last
      shipment = create_shipment_for(order)

      patch deliver_order_path(order)

      expect(response).to redirect_to(order_path(order))
      expect(shipment.reload).to be_pending
    end

    it "does not allow confirming another customer's order" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      post orders_path, params: { address_id: address.id }
      order = Order.last
      order.confirm!
      shipment = create_shipment_for(order)
      shipment.mark_shipped!

      other_customer = Customer.create!(name: "Outro confirmação", email: "other-deliver@example.com", password: "password123")
      delete customer_session_path
      post customer_session_path, params: { email: other_customer.email, password: "password123" }

      patch deliver_order_path(order)

      expect(response).to have_http_status(:not_found)
      expect(shipment.reload).not_to be_delivered
    end
  end

  def create_shipment_for(order, service: "Entrega padrão")
    order.seller_order.create_shipment!(
      carrier: "Entrega EloShop",
      service: service,
      shipping_cents: order.shipping_cents,
      estimated_days: 5
    )
  end

  def create_order_for(order_customer, idempotency_key:)
    Order.create!(
      customer: order_customer,
      status: :pending,
      subtotal_cents: 10_000,
      shipping_cents: 1_500,
      total_cents: 11_500,
      shipping_address_snapshot: { street: "Rua Teste", number: "1" },
      idempotency_key: idempotency_key
    )
  end
end
