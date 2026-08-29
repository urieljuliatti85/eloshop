require "test_helper"

module Checkout
  class CreateOrderTest < ActiveSupport::TestCase
    setup do
      @customer = customers(:one)
      @address = addresses(:one)
    end

    def build_cart_with_item(product, quantity:, variant: nil)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, product_variant: variant, quantity: quantity)
      cart
    end

    def build_product(**attrs)
      Product.create!({
        name: "Produto de teste",
        sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000,
        stock_quantity: 5,
        currency: "BRL",
        status: "active"
      }.merge(attrs))
    end

    def build_variant(product, **attrs)
      product.product_variants.create!({
        sku: "VAR-#{SecureRandom.hex(4)}",
        price_cents: 1500,
        stock_quantity: 5,
        size: "P",
        active: true
      }.merge(attrs))
    end

    test "creates the order and items, debits stock, and empties the cart" do
      product = build_product(stock_quantity: 5)
      cart = build_cart_with_item(product, quantity: 2)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert order.persisted?
      assert_equal 2000, order.subtotal_cents
      assert_equal CreateOrder::SHIPPING_CENTS, order.shipping_cents
      assert_equal 2000 + CreateOrder::SHIPPING_CENTS, order.total_cents
      assert_equal 3, product.reload.stock_quantity
      assert_empty cart.cart_items.reload
    end

    test "uses the product's current price, not the price when it was added to the cart" do
      product = build_product(price_cents: 1000)
      cart = build_cart_with_item(product, quantity: 1)

      product.update!(price_cents: 2000)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert_equal 2000, order.subtotal_cents
      assert_equal 2000, order.order_items.first.unit_price_cents
    end

    test "raises when stock became insufficient after the item was added to the cart" do
      product = build_product(stock_quantity: 5)
      cart = build_cart_with_item(product, quantity: 3)

      product.update!(stock_quantity: 1)

      assert_no_difference("Order.count") do
        assert_raises(CreateOrder::Failed) do
          CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
        end
      end

      assert_equal 1, product.reload.stock_quantity
    end

    test "raises when the product is no longer available" do
      product = build_product
      cart = build_cart_with_item(product, quantity: 1)

      product.discontinue!

      assert_no_difference("Order.count") do
        assert_raises(CreateOrder::Failed) do
          CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
        end
      end
    end

    test "raises for an empty cart" do
      cart = Cart.create!(session_token: SecureRandom.hex(10))

      assert_raises(CreateOrder::Failed) do
        CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      end
    end

    test "the same idempotency_key never creates a second order" do
      product = build_product
      cart = build_cart_with_item(product, quantity: 1)
      key = SecureRandom.hex(10)

      first_order = nil
      second_order = nil

      assert_difference("Order.count", 1) do
        first_order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: key).call
        second_order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: key).call
      end

      assert_equal first_order.id, second_order.id
    end

    test "order and order item preserve a snapshot unaffected by later changes" do
      original_street = @address.street
      product = build_product(name: "Nome original")
      cart = build_cart_with_item(product, quantity: 1)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      item = order.order_items.first

      product.update!(name: "Nome alterado", price_cents: 99_999)
      @address.update!(street: "Rua alterada")

      assert_equal "Nome original", item.reload.product_name
      assert_equal 1000, item.unit_price_cents
      assert_equal original_street, order.reload.shipping_address_snapshot["street"]
    end

    test "made_to_order item does not debit stock and snapshots the production time" do
      product = build_product(
        availability_type: "made_to_order", stock_quantity: 0,
        production_time_min_days: 7, production_time_max_days: 10
      )
      cart = build_cart_with_item(product, quantity: 3)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert_equal 0, product.reload.stock_quantity
      assert_equal "7 a 10 dias úteis", order.order_items.first.production_time_snapshot
    end

    test "made_to_order item is not blocked by requesting a quantity greater than stock_quantity" do
      product = build_product(availability_type: "made_to_order", stock_quantity: 0, production_time_min_days: 1, production_time_max_days: 2)
      cart = build_cart_with_item(product, quantity: 5)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert order.persisted?
    end

    test "variant item debits the variant's stock, not the product's, and snapshots size/color/material/sku" do
      product = build_product(stock_quantity: 0)
      variant = build_variant(product, stock_quantity: 3, price_cents: 1500, size: "P", color: "Azul")
      cart = build_cart_with_item(product, quantity: 2, variant: variant)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      item = order.order_items.first

      assert_equal 1, variant.reload.stock_quantity
      assert_equal 0, product.reload.stock_quantity
      assert_equal 3000, order.subtotal_cents
      assert_equal variant.sku, item.variant_sku
      assert_equal "P", item.size_snapshot
      assert_equal "Azul", item.color_snapshot
    end

    test "raises when the variant's stock became insufficient after the item was added to the cart" do
      product = build_product
      variant = build_variant(product, stock_quantity: 3)
      cart = build_cart_with_item(product, quantity: 3, variant: variant)

      variant.update!(stock_quantity: 1)

      assert_no_difference("Order.count") do
        assert_raises(CreateOrder::Failed) do
          CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
        end
      end

      assert_equal 1, variant.reload.stock_quantity
    end

    test "raises when the variant was deactivated after the item was added to the cart" do
      product = build_product
      variant = build_variant(product)
      cart = build_cart_with_item(product, quantity: 1, variant: variant)

      variant.update!(active: false)

      assert_raises(CreateOrder::Failed) do
        CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      end
    end

    test "raises when the product itself became unavailable even though the variant still has stock" do
      product = build_product
      variant = build_variant(product)
      cart = build_cart_with_item(product, quantity: 1, variant: variant)

      product.discontinue!

      assert_raises(CreateOrder::Failed) do
        CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      end
    end

    test "order preserves the variant snapshot even if the variant is later changed" do
      product = build_product
      variant = build_variant(product, size: "P", color: "Verde")
      cart = build_cart_with_item(product, quantity: 1, variant: variant)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      item = order.order_items.first

      variant.update!(size: "M", color: "Azul", price_cents: 9999)

      assert_equal "P", item.reload.size_snapshot
      assert_equal "Verde", item.color_snapshot
    end
  end
end
