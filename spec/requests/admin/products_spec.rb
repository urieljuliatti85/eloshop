# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin products", type: :request do
  before do
    clear_product_data!
  end

  let(:user) do
    User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123")
  end

  describe "GET /admin/products" do
    it "redirects unauthenticated users to login" do
      get admin_products_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated users to list products" do
      sign_in_as(user)

      get admin_products_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/products" do
    it "creates a product with valid attributes" do
      sign_in_as(user)

      expect do
        post admin_products_path, params: {
          product: {
            name: "Cesto de vime",
            description: "Cesto trançado à mão",
            price_cents: 5_990,
            currency: "BRL",
            sku: "CESTO-001",
            stock_quantity: 2
          }
        }
      end.to change(Product, :count).by(1)

      expect(response).to redirect_to(admin_product_path(Product.last))
    end

    it "does not create an invalid product" do
      sign_in_as(user)

      expect do
        post admin_products_path, params: { product: { name: "", sku: "", price_cents: 0, stock_quantity: 0 } }
      end.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/products/:id" do
    it "updates the product name" do
      sign_in_as(user)
      product = Product.create!(name: "Vaso original", sku: "PATCH-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      patch admin_product_path(product), params: { product: { name: "Vaso artesanal azul (edição limitada)" } }

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload.name).to eq("Vaso artesanal azul (edição limitada)")
    end
  end
end
