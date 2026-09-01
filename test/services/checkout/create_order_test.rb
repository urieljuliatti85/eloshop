require "test_helper"

module Checkout
  class CreateOrderTest < ActiveSupport::TestCase
    setup do
      @customer = customers(:one)
      @address = addresses(:one)
    end

    def build_cart_with_item(product, quantity:, variant: nil, personalizations: [])
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, product_variant: variant, quantity: quantity, personalizations: personalizations)
      cart
    end

    def build_product(**attrs)
      Product.create!({
        seller: sellers(:approved),
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

    def build_coupon(**attrs)
      Coupon.create!({
        code: "PROMO#{SecureRandom.hex(4)}",
        discount_type: "percentage",
        percentage: 10
      }.merge(attrs))
    end

    test "creates the order and items, debits stock, and empties the cart" do
      product = build_product(stock_quantity: 5)
      cart = build_cart_with_item(product, quantity: 2)

      order = nil
      capture_rails_events("checkout.order_created") do |events|
        order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

        assert_equal 1, events.size
        assert_equal order.id, events.first.dig(:payload, :order_id)
        assert_equal order.total_cents, events.first.dig(:payload, :amount_cents)
        assert_equal 1, events.first.dig(:payload, :item_count)
      end

      assert order.persisted?
      assert_equal 2000, order.subtotal_cents
      assert_equal CreateOrder::SHIPPING_CENTS, order.shipping_cents
      assert_equal 2000 + CreateOrder::SHIPPING_CENTS, order.total_cents
      assert_equal "Entrega padrão", order.shipment.service
      assert_equal 5, order.shipment.estimated_days
      assert_equal 3, product.reload.stock_quantity
      assert_empty cart.cart_items.reload
    end

    test "rejects a legacy or concurrently modified cart with more than one seller" do
      first_product = build_product
      second_product = build_product(name: "Segundo produto de teste")
      cart = build_cart_with_item(first_product, quantity: 1)
      cart.cart_items.create!(product: second_product, quantity: 1)
      second_product.update!(seller: sellers(:other))
      idempotency_key = SecureRandom.hex(10)

      error = assert_raises(CreateOrder::Failed) do
        CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: idempotency_key).call
      end

      assert_equal "O carrinho deve conter produtos de um único artesão.", error.message
      assert_not Order.exists?(idempotency_key: idempotency_key)
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

    test "order item snapshots the personalization label and value" do
      product = build_product
      option = product.personalization_options.create!(label: "Nome gravado", required: true, max_length: 30)
      cart = build_cart_with_item(product, quantity: 1, personalizations: [
        { "personalization_option_id" => option.id, "value" => "Maria" }
      ])

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      item = order.order_items.first

      assert_equal [ { label: "Nome gravado", value: "Maria" } ], item.personalization_entries
    end

    test "order preserves the personalization snapshot even if the option is later renamed or removed" do
      product = build_product
      option = product.personalization_options.create!(label: "Nome gravado", required: true, max_length: 30)
      cart = build_cart_with_item(product, quantity: 1, personalizations: [
        { "personalization_option_id" => option.id, "value" => "Maria" }
      ])

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
      item = order.order_items.first

      option.destroy!

      assert_equal [ { label: "Nome gravado", value: "Maria" } ], item.reload.personalization_entries
    end

    test "applies a valid coupon and increments its uses_count" do
      product = build_product(price_cents: 10_000)
      cart = build_cart_with_item(product, quantity: 1)
      coupon = build_coupon(discount_type: "percentage", percentage: 10)
      cart.update!(coupon: coupon)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert_equal coupon, order.coupon
      assert_equal 1_000, order.discount_cents
      assert_equal 10_000 - 1_000 + CreateOrder::SHIPPING_CENTS, order.total_cents
      assert_equal 1, coupon.reload.uses_count
      assert_nil cart.reload.coupon
    end

    test "a fixed coupon never makes the total negative" do
      product = build_product(price_cents: 1_000)
      cart = build_cart_with_item(product, quantity: 1)
      coupon = build_coupon(discount_type: "fixed", percentage: nil, amount_cents: 50_000)
      cart.update!(coupon: coupon)

      order = CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call

      assert_equal 1_000, order.discount_cents
      assert_equal CreateOrder::SHIPPING_CENTS, order.total_cents
    end

    test "raises when the coupon expired after being applied to the cart" do
      product = build_product
      cart = build_cart_with_item(product, quantity: 1)
      coupon = build_coupon(expires_at: 1.day.from_now)
      cart.update!(coupon: coupon)

      travel_to 2.days.from_now do
        assert_no_difference("Order.count") do
          assert_raises(CreateOrder::Failed) do
            CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
          end
        end
      end

      assert_equal 0, coupon.reload.uses_count
    end

    test "raises when the coupon reached its usage limit before checkout completes" do
      product = build_product
      cart = build_cart_with_item(product, quantity: 1)
      coupon = build_coupon(max_uses: 1, uses_count: 1)
      cart.update!(coupon: coupon)

      assert_no_difference("Order.count") do
        assert_raises(CreateOrder::Failed) do
          CreateOrder.new(cart: cart, customer: @customer, address: @address, idempotency_key: SecureRandom.hex(10)).call
        end
      end
    end
  end
end
