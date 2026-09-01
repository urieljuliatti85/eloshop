# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:customer) { Customer.create!(name: "Cliente payments", email: "pay@example.com", password: "password123") }
  let(:order) do
    Order.create!(
      customer: customer,
      status: "pending",
      subtotal_cents: 1000,
      shipping_cents: 500,
      total_cents: 1500,
      shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
      idempotency_key: SecureRandom.uuid
    )
  end

  before do
    Payment.create!(order: order, gateway: "fake", external_id: "pay-#{SecureRandom.hex(4)}", amount_cents: 1500, status: "pending")
  end

  describe "GET /orders/:order_id/payment/new" do
    it "redirects unauthenticated visitors to customer login" do
      get new_order_payment_path(order)

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "forbids access to another customer's order" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      other_customer = Customer.create!(name: "Outro", email: "other@example.com", password: "password123")
      other_order = Order.create!(
        customer: other_customer,
        status: "pending",
        subtotal_cents: 1000,
        shipping_cents: 500,
        total_cents: 1500,
        shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
        idempotency_key: SecureRandom.uuid
      )

      get new_order_payment_path(other_order)

      expect(response).to have_http_status(:not_found)
    end

    it "allows the owner to view the payment page" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      get new_order_payment_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="card_number"')
      expect(response.body).not_to include('name="cvv"')
    end
  end

  describe "GET /orders/:order_id/payment/status" do
    it "returns the owner's current payment without creating a charge" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect {
        get status_order_payment_path(order)
      }.not_to change(Payment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("payment-status")
    end

    it "does not expose another customer's payment" do
      other_customer = Customer.create!(name: "Outro", email: "other-status@example.com", password: "password123")
      post customer_session_path, params: { email: other_customer.email, password: "password123" }

      get status_order_payment_path(order)

      expect(response).to have_http_status(:not_found)
    end
  end
end
