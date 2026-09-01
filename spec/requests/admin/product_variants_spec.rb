# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin product variants", type: :request do
  let(:user) { User.create!(email_address: "variant-admin@example.com", password: "password", password_confirmation: "password") }
  let(:product) { Product.create!(seller: approved_seller, name: "Camiseta variante", sku: "VAR-ADMIN-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active, availability_type: "standard") }
  let(:variant) { product.product_variants.create!(sku: "VAR-ADMIN-001-M", price_cents: 7_500, stock_quantity: 4, size: "M") }

  describe "GET /admin/products/:product_id/product_variants/new" do
    it "redirects unauthenticated users" do
      get new_admin_product_product_variant_path(product)

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated admins to view the form" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get new_admin_product_product_variant_path(product)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/products/:product_id/product_variants" do
    it "creates a variant with valid params" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_product_product_variants_path(product), params: {
          product_variant: { sku: "CAMISETA-001-M", price_cents: 7_500, stock_quantity: 4, size: "M" }
        }
      end.to change(ProductVariant, :count).by(1)

      expect(response).to redirect_to(admin_product_path(product))
    end

    it "rejects invalid params" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_product_product_variants_path(product), params: {
          product_variant: { sku: "", price_cents: 7_500, stock_quantity: 4, size: "M" }
        }
      end.not_to change(ProductVariant, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/products/:product_id/product_variants/:id" do
    it "updates the variant" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch admin_product_product_variant_path(product, variant), params: { product_variant: { stock_quantity: 9 } }

      expect(response).to redirect_to(admin_product_path(product))
      expect(variant.reload.stock_quantity).to eq(9)
    end
  end

  describe "DELETE /admin/products/:product_id/product_variants/:id" do
    it "destroys a never-ordered variant" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      path = admin_product_product_variant_path(product, variant)

      expect do
        delete path
      end.to change(ProductVariant, :count).by(-1)

      expect(response).to redirect_to(admin_product_path(product))
    end

    it "does not destroy a variant already referenced by an order item" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      customer = Customer.create!(name: "Cliente ordem", email: "order-variant@example.com", password: "password123")
      order = Order.create!(
        customer: customer,
        status: "pending",
        subtotal_cents: 1000,
        shipping_cents: 500,
        total_cents: 1500,
        shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
        idempotency_key: SecureRandom.uuid
      )
      seller_order = order.seller_orders.create!(seller: product.seller, subtotal_cents: 1000, shipping_cents: 500, total_cents: 1500, platform_fee_cents: 150, seller_amount_cents: 1350)
      OrderItem.create!(order: order, seller_order: seller_order, product: product, product_variant: variant, product_name: product.name, sku: variant.sku, unit_price_cents: variant.price_cents, quantity: 1)

      expect do
        delete admin_product_product_variant_path(product, variant)
      end.not_to change(ProductVariant, :count)

      expect(response).to redirect_to(admin_product_path(product))
      follow_redirect!
      expect(response.body).to include("não pode ser excluída")
    end
  end
end
