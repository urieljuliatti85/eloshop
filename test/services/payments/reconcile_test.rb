require "test_helper"

module Payments
  class ReconcileTest < ActiveSupport::TestCase
    setup do
      @gateway = stub_gateway("fake", payment_status: "pending")
      @service = Reconcile.new(gateway: @gateway)
    end

    test "skips payments still pending on the gateway" do
      payment = create_pending_payment(age: 15.minutes)
      stub_gateway_status(@gateway, payment, "pending")

      assert_no_difference("PaymentEvent.count") { @service.call }
      assert payment.reload.pending?
    end

    test "reconciles an approved payment that missed the webhook" do
      order, payment = create_pending_payment_with_order(age: 15.minutes)
      stub_gateway_status(@gateway, payment, "approved")

      assert_difference("PaymentEvent.count", 1) { @service.call }

      assert payment.reload.paid?
      assert order.reload.confirmed?
    end

    test "reconciles a declined payment" do
      order, payment = create_pending_payment_with_order(age: 15.minutes)
      stub_gateway_status(@gateway, payment, "declined")

      @service.call

      assert payment.reload.failed?
      assert order.reload.pending?
    end

    test "skips payments newer than the minimum age" do
      _order, payment = create_pending_payment_with_order(age: 5.minutes)
      stub_gateway_status(@gateway, payment, "approved")

      assert_no_difference("PaymentEvent.count") { @service.call }
      assert payment.reload.pending?
    end

    test "skips payments from other gateways" do
      _order, payment = create_pending_payment_with_order(age: 15.minutes)
      payment.update_columns(gateway: "other_gateway")
      stub_gateway_status(@gateway, payment, "approved")

      assert_no_difference("PaymentEvent.count") { @service.call }
    end

    # Quando o webhook já confirmou o pagamento (status paid), a reconciliação
    # não o encontra (filtra por pending) e portanto não cria evento nem altera
    # estado — é segura de rodar mesmo após a confirmação.
    test "is harmless when the webhook already confirmed the payment" do
      order, payment = create_pending_payment_with_order(age: 15.minutes)
      ProcessWebhook.new(event_id: "mp-webhook-event", external_id: payment.external_id, status: "approved").call
      assert payment.reload.paid?
      stub_gateway_status(@gateway, payment, "approved")

      assert_no_difference("PaymentEvent.count") { @service.call }
      assert payment.reload.paid?
      assert order.reload.confirmed?
    end

    test "continues processing remaining payments when one fails" do
      first_order, first_payment = create_pending_payment_with_order(age: 15.minutes)
      _second_order, second_payment = create_pending_payment_with_order(age: 15.minutes)

      failing_gateway = Object.new
      failing_gateway.define_singleton_method(:name) { "fake" }
      failing_gateway.define_singleton_method(:payment_status) do |external_id:|
        raise StandardError, "network error" if external_id == first_payment.external_id
        "approved"
      end

      Reconcile.new(gateway: failing_gateway).call

      assert first_payment.reload.pending?
      assert second_payment.reload.paid?
    end

    test "emits a reconciled event for updated payments" do
      _order, payment = create_pending_payment_with_order(age: 15.minutes)
      stub_gateway_status(@gateway, payment, "approved")

      capture_rails_events("payment.reconciled") do |events|
        @service.call
        assert_equal 1, events.size
        assert_equal payment.id, events.first.dig(:payload, :payment_id)
        assert_equal "approved", events.first.dig(:payload, :status)
      end
    end

    test "emits a reconcile_failed event when the gateway raises" do
      _order, payment = create_pending_payment_with_order(age: 15.minutes)
      @gateway.define_singleton_method(:payment_status) { |external_id:| raise StandardError, "timeout" }

      capture_rails_events("payment.reconcile_failed") do |events|
        @service.call
        assert_equal 1, events.size
        assert_equal payment.id, events.first.dig(:payload, :payment_id)
      end
    end

    private

    def stub_gateway(gateway_name, payment_status:)
      Object.new.tap do |gw|
        gw.define_singleton_method(:name) { gateway_name }
        gw.define_singleton_method(:payment_status) { |external_id:| payment_status }
        gw.define_singleton_method(:authorize) do |order:, idempotency_key:, application_fee_cents:|
          Gateways::Intent.new(external_id: "fake_#{SecureRandom.hex(10)}")
        end
      end
    end

    def stub_gateway_status(gateway, payment, status)
      gateway.define_singleton_method(:payment_status) do |external_id:|
        external_id == payment.external_id ? status : "pending"
      end
    end

    def create_pending_payment(age:)
      customer = Customer.create!(name: "C", email: "#{SecureRandom.hex(4)}@test.com", password: "password123")
      address = customer.addresses.create!(street: "R", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "Produto #{SecureRandom.hex(4)}", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order, gateway: @gateway).call
      payment.update_columns(created_at: age.ago)
      payment
    end

    def create_pending_payment_with_order(age:)
      payment = create_pending_payment(age: age)
      [ payment.order, payment ]
    end
  end
end
