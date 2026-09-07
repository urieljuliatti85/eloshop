require "test_helper"

module Orders
  class CancelTest < ActiveSupport::TestCase
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

    def create_payment(order, status:)
      order.payments.create!(
        gateway: "mercado_pago",
        status: status,
        amount_cents: order.total_cents,
        application_fee_cents: order.seller_order.platform_fee_cents,
        idempotency_key: SecureRandom.uuid,
        external_id: "mp-#{SecureRandom.hex(4)}"
      )
    end

    test "cancels a pending order and restores stock" do
      order, product = build_order(stock_quantity: 5)

      Cancel.new.call(order)

      assert order.reload.cancelled?
      assert_equal 5, product.reload.stock_quantity
    end

    test "cancels a confirmed order" do
      order, = build_order
      order.confirm!

      Cancel.new.call(order)

      assert order.reload.cancelled?
    end

    test "raises for an order that already has an authorized payment" do
      order, product = build_order
      create_payment(order, status: "paid")

      assert_raises(Cancel::InvalidCancellation) { Cancel.new.call(order) }
      assert order.reload.pending?
      assert_equal 4, product.reload.stock_quantity
    end

    test "raises for an order that is already cancelled" do
      order, = build_order
      order.cancel!

      assert_raises(Cancel::InvalidCancellation) { Cancel.new.call(order) }
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

      Cancel.new.call(order)

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

      Cancel.new.call(order)

      assert order.reload.cancelled?
      assert_equal 0, product.reload.stock_quantity
    end
  end
end
