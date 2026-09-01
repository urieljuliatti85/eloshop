# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Carts", type: :request do
  let(:product) do
    Product.create!(seller: approved_seller, name: "Vaso cart", sku: "CART-001", price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active)
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

  describe "POST /cart/apply_coupon" do
    it "applies a valid coupon" do
      Coupon.create!(code: "PROMO10", discount_type: "percentage", percentage: 10)
      post cart_items_path, params: { product_id: product.id, quantity: 1 }

      post apply_coupon_cart_path, params: { code: "promo10" }

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("PROMO10")
    end

    it "rejects an invalid coupon" do
      post apply_coupon_cart_path, params: { code: "DOES-NOT-EXIST" }

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("inválido")
    end

    it "rejects an expired coupon" do
      Coupon.create!(code: "EXPIRADO", discount_type: "percentage", percentage: 10, expires_at: 1.day.ago)
      post cart_items_path, params: { product_id: product.id, quantity: 1 }

      post apply_coupon_cart_path, params: { code: "EXPIRADO" }

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("inválido")
    end

    it "rate limits repeated attempts to guess a coupon code" do
      10.times { post apply_coupon_cart_path, params: { code: "TENTATIVA" } }

      post apply_coupon_cart_path, params: { code: "TENTATIVA" }

      follow_redirect!
      expect(response.body).to include("Muitas tentativas")
    end
  end

  describe "DELETE /cart/remove_coupon" do
    it "removes the applied coupon" do
      coupon = Coupon.create!(code: "PROMO10", discount_type: "percentage", percentage: 10)
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      post apply_coupon_cart_path, params: { code: coupon.code }

      delete remove_coupon_cart_path

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).not_to include("PROMO10")
    end
  end
end
