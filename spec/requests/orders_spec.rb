# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:customer) { Customer.create!(name: "Cliente checkout", email: "checkout@example.com", password: "password123") }
  let(:product) { Product.create!(name: "Vaso checkout", sku: "CHK-001", price_cents: 10_000, stock_quantity: 3, currency: "BRL", status: :active) }

  def sign_in_customer
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  def add_to_cart(quantity: 1)
    post cart_items_path, params: { product_id: product.id, quantity: quantity }
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
  end

  describe "POST /orders" do
    it "creates the order and redirects to it" do
      sign_in_customer
      add_to_cart
      address = customer.addresses.create!(street: "Rua Teste", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")

      expect do
        post orders_path, params: { address_id: address.id }
      end.to change(Order, :count).by(1)

      order = Order.last
      expect(response).to redirect_to(order_path(order))
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
end
