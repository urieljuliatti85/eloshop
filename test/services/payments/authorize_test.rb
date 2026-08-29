require "test_helper"

module Payments
  class AuthorizeTest < ActiveSupport::TestCase
    def build_order
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)

      Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
    end

    test "creates a payment for the order" do
      order = build_order

      payment = Authorize.new(order: order).call

      assert payment.persisted?
      assert_equal order.total_cents, payment.amount_cents
      assert payment.pending?
    end

    test "reuses an existing pending payment instead of creating a new one" do
      order = build_order

      first = Authorize.new(order: order).call
      second = Authorize.new(order: order).call

      assert_equal first.id, second.id
      assert_equal 1, order.payments.count
    end

    test "creates a new payment after a previous one was declined" do
      order = build_order

      failed_payment = Authorize.new(order: order).call
      failed_payment.update!(status: "failed")

      retry_payment = Authorize.new(order: order).call

      assert_not_equal failed_payment.id, retry_payment.id
      assert_equal 2, order.payments.count
    end
  end
end
