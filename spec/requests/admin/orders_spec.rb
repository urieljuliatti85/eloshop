# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin orders", type: :request do
  let(:user) { User.create!(email_address: "orders-admin@example.com", password: "password", password_confirmation: "password") }
  let(:customer) { Customer.create!(name: "Cliente order", email: "order@example.com", password: "password123") }
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

  describe "GET /admin/orders" do
    it "redirects unauthenticated users" do
      get admin_orders_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated admins to list orders" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/orders/:id" do
    it "allows admins to view any order" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
    end
  end
end
