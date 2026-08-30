# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wishlists", type: :request do
  let(:customer) { Customer.create!(name: "Cliente wishlist", email: "wish@example.com", password: "password123") }
  let(:product) { Product.create!(name: "Vaso wishlist", sku: "WISH-001", price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active) }

  describe "GET /wishlist" do
    it "redirects unauthenticated visitors to customer login" do
      get wishlist_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "lists the customer favorites" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      customer.wishlist_items.create!(product: product)

      get wishlist_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end
  end
end
