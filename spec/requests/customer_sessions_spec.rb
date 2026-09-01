# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer sessions", type: :request do
  let(:customer) { Customer.create!(name: "Cliente", email: "customer@example.com", password: "password123") }

  describe "POST /customer_session" do
    it "logs in with valid credentials and associates the current cart" do
      get products_path

      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect(response).to redirect_to(root_path)
      expect(response.cookies).to have_key("customer_session_id")
      expect(Cart.order(:created_at).last.customer).to eq(customer)
    end

    it "returns to checkout after authentication" do
      product = Product.create!(seller: approved_seller, name: "Retorno", sku: "RETURN-LOGIN", price_cents: 1000, stock_quantity: 1, status: :active)
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      get new_order_path

      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect(response).to redirect_to(new_order_path)
    end

    it "rejects invalid credentials" do
      post customer_session_path, params: { email: customer.email, password: "wrong" }

      expect(response).to redirect_to(new_customer_session_path)
      expect(response.cookies["customer_session_id"]).to be_nil
    end

    it "does not grant admin access" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      get admin_products_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "DELETE /customer_session" do
    it "terminates the customer session" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      delete customer_session_path

      expect(response).to redirect_to(root_path)
      expect(response.cookies["customer_session_id"]).to be_nil
    end
  end

  describe "session expiration" do
    it "keeps an active session valid within the inactivity window" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      travel CustomerSession::INACTIVITY_TIMEOUT - 1.day do
        get new_order_path

        expect(response).not_to redirect_to(new_customer_session_path)
      end
    end

    it "expires a session past the inactivity window" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      travel CustomerSession::INACTIVITY_TIMEOUT + 1.day do
        get new_order_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end
  end
end
