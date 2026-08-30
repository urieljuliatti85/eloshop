# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Storefront products", type: :request do
  before do
    clear_product_data!
  end

  describe "GET /produtos" do
    it "lists only active products" do
      active = Product.create!(name: "Vaso ativo", sku: "STORE-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      draft = Product.create!(name: "Caneca rascunho", sku: "STORE-002", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :draft)

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).not_to include(draft.name)
    end
  end

  describe "GET /produtos/:slug" do
    it "renders an active product by slug" do
      product = Product.create!(name: "Vaso storefront", sku: "STORE-003", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      get product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end

    it "returns 404 for a draft product" do
      product = Product.create!(name: "Caneca draft", sku: "STORE-004", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :draft)

      get product_path(product)

      expect(response).to have_http_status(:not_found)
    end
  end
end
