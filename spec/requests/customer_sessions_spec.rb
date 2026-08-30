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
end
