# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wishlist items", type: :request do
  let(:customer) { Customer.create!(name: "Cliente wishlist item", email: "wish-item@example.com", password: "password123") }
  let(:product) { Product.create!(name: "Vaso wish item", sku: "WISH-ITEM-001", price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active) }

  describe "POST /wishlist_items" do
    it "redirects unauthenticated visitors to customer login" do
      post wishlist_items_path, params: { product_id: product.id }

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "favorites a product" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post wishlist_items_path, params: { product_id: product.id }
      end.to change(WishlistItem, :count).by(1)
    end

    it "does not duplicate a favorite" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      customer.wishlist_items.create!(product: product)

      expect do
        post wishlist_items_path, params: { product_id: product.id }
      end.not_to change(WishlistItem, :count)
    end

    it "removes a favorite item" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      item = customer.wishlist_items.create!(product: product)

      expect do
        delete wishlist_item_path(item)
      end.to change(WishlistItem, :count).by(-1)
    end

    it "does not allow a customer to remove another customer's wishlist item" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      other_item = Customer.create!(name: "Outro", email: "outro@example.com", password: "password123").wishlist_items.create!(product: product)

      delete wishlist_item_path(other_item)

      expect(response).to have_http_status(:not_found)
      expect(WishlistItem.exists?(other_item.id)).to be(true)
    end

    it "moves a directly purchasable product to the cart and removes it from wishlist" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      item = customer.wishlist_items.create!(product: product)

      expect do
        post move_to_cart_wishlist_item_path(item)
      end.to change(CartItem, :count).by(1)

      expect(response).to redirect_to(cart_path)
      expect(customer.wishlist_items.count).to eq(0)
    end

    it "does not move a product that requires choosing a variant" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      variant_product = Product.create!(name: "Camisa variante", sku: "VAR-WISH-001", price_cents: 7_500, stock_quantity: 5, currency: "BRL", status: :active)
      ProductVariant.create!(product: variant_product, sku: "VAR-WISH-001-A", price_cents: 7_500, stock_quantity: 3, color: "Azul")
      item = customer.wishlist_items.create!(product: variant_product)

      expect do
        post move_to_cart_wishlist_item_path(item)
      end.not_to change(CartItem, :count)

      expect(response).to redirect_to(product_path(variant_product))
      expect(customer.wishlist_items.count).to eq(1)
    end
  end
end
