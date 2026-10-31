require "test_helper"

module Payments
  class ProcessWebhookTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    def build_order_with_payment(product_name: "P")
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: product_name, sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
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
      assert order.seller_order.confirmed?

      notification = order.customer.notifications.order_confirmed.last
      assert notification.present?
      assert_equal Rails.application.routes.url_helpers.order_path(order), notification.url

      assert order.order_events.webhook_applied.exists?
      assert order.order_events.order_confirmed.exists?
    end

    test "records the processor fee returned by the gateway" do
      _order, payment = build_order_with_payment

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved", processor_fee_cents: 123).call

      assert_equal 123, payment.reload.processor_fee_cents
    end

    test "declined event marks the payment as failed and leaves the order pending" do
      order, payment = build_order_with_payment

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call

      assert payment.reload.failed?
      assert order.reload.pending?
    end

    test "declined event notifies platform admins" do
      admin = User.create!(email_address: "#{SecureRandom.hex(4)}@example.com", password: "password", password_confirmation: "password")
      order, payment = build_order_with_payment

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call

      notification = admin.notifications.payment_declined.last
      assert notification.present?
      assert_includes notification.body, order.id.to_s
    end

    test "a second declined event for an already failed payment does not notify admins again" do
      admin = User.create!(email_address: "#{SecureRandom.hex(4)}@example.com", password: "password", password_confirmation: "password")
      _order, payment = build_order_with_payment
      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call

      assert_no_difference -> { admin.notifications.payment_declined.count } do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call
      end
    end

    test "charged_back event opens a chargeback alert without touching payment, order or funnel" do
      order, payment = build_order_with_payment
      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call
      seller = order.seller_order.seller

      assert_enqueued_emails 1 do
        assert_no_difference -> { FunnelEvent.where(event_name: "payment_failed").count } do
          ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "charged_back").call
        end
      end

      alert = seller.fraud_alerts.open.find_by!(rule: "chargeback")
      assert_equal [ order.id ], alert.detail["order_ids"]
      assert payment.reload.paid?
      assert order.reload.confirmed?
    end

    test "a second chargeback of the same seller joins the open alert without notifying again" do
      order, payment = build_order_with_payment
      other_order, other_payment = build_order_with_payment(product_name: "Outra peça")
      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "charged_back").call

      assert_no_enqueued_emails do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: other_payment.external_id, status: "charged_back").call
      end

      alert = order.seller_order.seller.fraud_alerts.open.where(rule: "chargeback").sole
      assert_equal [ order.id, other_order.id ].sort, alert.detail["order_ids"]
    end

    test "the same charged_back event_id twice creates a single alert" do
      order, payment = build_order_with_payment
      event_id = SecureRandom.hex(10)

      2.times { ProcessWebhook.new(event_id: event_id, external_id: payment.external_id, status: "charged_back").call }

      assert_equal 1, order.seller_order.seller.fraud_alerts.where(rule: "chargeback").count
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

    test "an approved retry does not overwrite a refunded payment" do
      order, payment = build_order_with_payment
      payment.update!(status: :refunded, refunded_amount_cents: payment.amount_cents, application_fee_refunded_cents: payment.application_fee_cents)
      order.seller_order.update!(status: :refunded, refunded_amount_cents: payment.amount_cents, platform_fee_refunded_cents: payment.application_fee_cents)
      order.update!(status: :refunded)

      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call

      assert payment.reload.refunded?
      assert order.reload.refunded?
    end

    test "raises OrderNotFound for an unknown external_id" do
      assert_raises(ProcessWebhook::OrderNotFound) do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: "unknown", status: "approved").call
      end
    end
  end
end
