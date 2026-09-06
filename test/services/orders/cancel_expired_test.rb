require "test_helper"

module Orders
  class CancelExpiredTest < ActiveSupport::TestCase
    def build_order(stock_quantity: 5)
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000, stock_quantity: stock_quantity, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)

      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      [ order, product ]
    end

    def create_pix_payment(order, expires_at:, status: "pending")
      order.payments.create!(
        gateway: "mercado_pago",
        status: status,
        amount_cents: order.total_cents,
        application_fee_cents: order.seller_order.platform_fee_cents,
        idempotency_key: SecureRandom.uuid,
        external_id: "mp-#{SecureRandom.hex(4)}",
        expires_at: expires_at
      )
    end

    test "cancels a pending order whose PIX expired over an hour ago and restores stock" do
      order, product = build_order(stock_quantity: 5)
      create_pix_payment(order, expires_at: 2.hours.ago)

      CancelExpired.new.call

      assert order.reload.cancelled?
      assert_equal 5, product.reload.stock_quantity
    end

    test "does not cancel an order within the one hour grace period" do
      order, = build_order
      create_pix_payment(order, expires_at: 30.minutes.ago)

      CancelExpired.new.call

      assert order.reload.pending?
    end

    test "does not cancel an order whose payment was already paid" do
      order, product = build_order
      create_pix_payment(order, expires_at: 2.hours.ago, status: "paid")

      CancelExpired.new.call

      assert order.reload.pending?
      assert_equal 4, product.reload.stock_quantity
    end

    test "restores variant stock, not product stock, when the item has a variant" do
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000, currency: "BRL", status: "active")
      variant = product.product_variants.create!(sku: "SKU-VAR-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 3, color: "Azul")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, product_variant: variant, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      create_pix_payment(order, expires_at: 2.hours.ago)

      CancelExpired.new.call

      assert order.reload.cancelled?
      assert_equal 3, variant.reload.stock_quantity
    end

    test "does not restore stock for made-to-order products" do
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000, currency: "BRL", status: "active", availability_type: "made_to_order",
        production_time_min_days: 5, production_time_max_days: 10)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      create_pix_payment(order, expires_at: 2.hours.ago)

      CancelExpired.new.call

      assert order.reload.cancelled?
      assert_equal 0, product.reload.stock_quantity
    end

    test "ignores orders without a PIX payment at all" do
      order, = build_order

      assert_nothing_raised { CancelExpired.new.call }
      assert order.reload.pending?
    end
  end
end
