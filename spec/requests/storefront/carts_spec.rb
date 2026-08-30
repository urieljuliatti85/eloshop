# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Carts", type: :request do
  let(:product) do
    Product.create!(name: "Vaso cart", sku: "CART-001", price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active)
  end

  describe "GET /cart" do
    it "shows the cart without authentication" do
      get cart_path

      expect(response).to have_http_status(:ok)
    end

    it "keeps cart data across requests in the same session" do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }

      get cart_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end
  end
end
