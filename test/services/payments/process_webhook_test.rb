require "test_helper"

module Payments
  class ProcessWebhookTest < ActiveSupport::TestCase
    def build_order_with_payment
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order).call
      [ order, payment ]
    end

    test "approved event marks the payment as paid and confirms the order" do
      order, payment = build_order_with_payment

      capture_rails_events("payment.webhook_applied") do |events|
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call

        assert_equal 1, events.size
        assert_equal payment.id, events.first.dig(:payload, :payment_id)
        assert_equal "paid", events.first.dig(:payload, :status)
      end

      assert payment.reload.paid?
      assert order.reload.confirmed?
    end

    test "declined event marks the payment as failed and leaves the order pending" do
      order, payment = build_order_with_payment

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call

      assert payment.reload.failed?
      assert order.reload.pending?
    end

    test "the same event_id processed twice has no additional effect" do
      _order, payment = build_order_with_payment
      event_id = SecureRandom.hex(10)

      ProcessWebhook.new(event_id: event_id, external_id: payment.external_id, status: "approved").call

      assert_no_difference("PaymentEvent.count") do
        ProcessWebhook.new(event_id: event_id, external_id: payment.external_id, status: "approved").call
      end

      assert payment.reload.paid?
    end

    test "a second approved event with a different event_id does not raise" do
      order, payment = build_order_with_payment

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call

      assert_nothing_raised do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call
      end

      assert order.reload.confirmed?
    end

    test "raises OrderNotFound for an unknown external_id" do
      assert_raises(ProcessWebhook::OrderNotFound) do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: "unknown", status: "approved").call
      end
    end
  end
end
