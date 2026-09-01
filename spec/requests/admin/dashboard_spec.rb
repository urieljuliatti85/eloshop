# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:user) { User.create!(email_address: "dashboard-admin@example.com", password: "password", password_confirmation: "password") }

  describe "GET /admin" do
    it "redirects unauthenticated users to login" do
      get admin_root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "shows pending orders, low stock and sold out products, and pending reviews" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      customer = Customer.create!(name: "Cliente dashboard", email: "dash@example.com", password: "password123")
      pending_product = Product.create!(seller: approved_seller, name: "Vaso baixo estoque", sku: "DASH-001", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)
      sold_out_product = Product.create!(seller: approved_seller, name: "Vaso esgotado", sku: "DASH-002", price_cents: 5_000, stock_quantity: 0, currency: "BRL", status: :sold_out)
      order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1_000, shipping_cents: 500, total_cents: 1_500,
        shipping_address_snapshot: { street: "Rua", number: "1" }, idempotency_key: SecureRandom.uuid
      )
      review = customer.reviews.create!(product: pending_product, rating: 5, comment: "Ótimo", status: "pending")

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pending_product.name)
      expect(response.body).to include(sold_out_product.name)
      expect(response.body).to include(order.customer.name)
      expect(response.body).to include(review.customer.name)
      expect(response.body).to include("Área administrativa")
      expect(response.body).to include("Acompanhe o que precisa de atenção")
      expect(response.body).to include("admin-sidebar")
    end
  end
end
