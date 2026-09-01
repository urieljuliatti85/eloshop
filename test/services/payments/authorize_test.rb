require "test_helper"

module Payments
  class AuthorizeTest < ActiveSupport::TestCase
    class PixGateway
      attr_reader :keys

      def initialize(expires_at: 30.minutes.from_now, fail_once: false)
        @expires_at = expires_at
        @fail_once = fail_once
        @keys = []
      end

      def name = "mercado_pago"

      def authorize(order:, idempotency_key:)
        @keys << idempotency_key
        if @fail_once
          @fail_once = false
          raise Net::ReadTimeout
        end

        Gateways::Intent.new(
          external_id: "mp-#{idempotency_key}",
          qr_code: "pix-code",
          expires_at: @expires_at
        )
      end
    end

    def build_order
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)

      Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
    end

    test "creates a payment for the order" do
      order = build_order

      payment = nil
      capture_rails_events("payment.attempt_created") do |events|
        payment = Authorize.new(order: order).call

        assert_equal 1, events.size
        assert_equal payment.id, events.first.dig(:payload, :payment_id)
        assert_equal order.id, events.first.dig(:payload, :order_id)
        assert_equal "fake", events.first.dig(:payload, :gateway)
      end

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

    test "replaces an expired pending payment with a new attempt" do
      order = build_order
      expired_gateway = PixGateway.new(expires_at: 1.minute.ago)
      expired = Authorize.new(order: order, gateway: expired_gateway).call

      current_gateway = PixGateway.new
      current = Authorize.new(order: order, gateway: current_gateway).call

      assert expired.reload.failed?
      assert current.pending?
      assert_not_equal expired.id, current.id
      assert_not_equal expired.idempotency_key, current.idempotency_key
    end

    test "resumes a processing attempt with the same key after timeout" do
      order = build_order
      gateway = PixGateway.new(fail_once: true)

      assert_raises(Net::ReadTimeout) { Authorize.new(order: order, gateway: gateway).call }
      processing = order.payments.processing.sole

      payment = Authorize.new(order: order, gateway: gateway).call

      assert_equal processing.id, payment.id
      assert_equal [ processing.idempotency_key, processing.idempotency_key ], gateway.keys
      assert payment.pending?
      assert_equal 1, order.payments.count
    end
  end
end
