# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cart items", type: :request do
  let(:product) do
    Product.create!(name: "Vaso cart item", sku: "CI-001", price_cents: 5_000, stock_quantity: 3, currency: "BRL", status: :active)
  end

  describe "POST /cart_items" do
    it "adds a product to the cart" do
      expect do
        post cart_items_path, params: { product_id: product.id, quantity: 1 }
      end.to change(CartItem, :count).by(1)

      expect(response).to redirect_to(cart_path)
    end

    it "sums quantity when the same product is added twice" do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }

      expect do
        post cart_items_path, params: { product_id: product.id, quantity: 1 }
      end.not_to change(CartItem, :count)

      expect(CartItem.last.quantity).to eq(2)
    end

    it "rejects a quantity greater than the available stock" do
      expect do
        post cart_items_path, params: { product_id: product.id, quantity: 10 }
      end.not_to change(CartItem, :count)

      expect(response).to redirect_to(product_path(product))
    end

    it "requires a variant when the product has variants" do
      product.product_variants.create!(sku: "CI-001-M", price_cents: 5_000, stock_quantity: 2, size: "M")

      expect do
        post cart_items_path, params: { product_id: product.id, quantity: 1 }
      end.not_to change(CartItem, :count)
    end
  end

  describe "PATCH /cart_items/:id" do
    it "updates the quantity" do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      item = CartItem.last

      patch cart_item_path(item), params: { quantity: 2 }

      expect(response).to redirect_to(cart_path)
      expect(item.reload.quantity).to eq(2)
    end

    it "rejects a quantity greater than the available stock" do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      item = CartItem.last

      patch cart_item_path(item), params: { quantity: 99 }

      expect(response).to redirect_to(cart_path)
      expect(item.reload.quantity).to eq(1)
    end
  end

  describe "DELETE /cart_items/:id" do
    it "removes the item from the cart" do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      item = CartItem.last

      expect do
        delete cart_item_path(item)
      end.to change(CartItem, :count).by(-1)

      expect(response).to redirect_to(cart_path)
    end
  end
end
