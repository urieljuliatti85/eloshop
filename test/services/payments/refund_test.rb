require "test_helper"

module Payments
  class RefundTest < ActiveSupport::TestCase
    def build_paid_payment
      customer = customers(:one)
      address = addresses(:one)
      product = Product.create!(seller: sellers(:approved), name: "Reembolsável", sku: "REF-#{SecureRandom.hex(4)}", price_cents: 1_000, stock_quantity: 2, status: :active)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order).call
      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call
      payment.reload
    end

    test "applies partial then full refunds and reverses the fee proportionally" do
      payment = build_paid_payment
      seller_order = payment.order.seller_order

      partial = Refund.new(payment: payment, amount_cents: 500, idempotency_key: "partial-refund").call

      assert partial.approved?
      assert_equal 500, payment.reload.refunded_amount_cents
      assert_equal 30, payment.application_fee_refunded_cents
      assert payment.partially_refunded?
      assert seller_order.reload.partially_refunded?
      assert payment.order.reload.partially_refunded?

      final = Refund.new(payment: payment, amount_cents: 2_000, idempotency_key: "final-refund").call

      assert final.approved?
      assert_equal 2_500, payment.reload.refunded_amount_cents
      assert_equal 150, payment.application_fee_refunded_cents
      assert payment.refunded?
      assert seller_order.reload.refunded?
      assert payment.order.reload.refunded?
    end

    test "reuses an approved refund with the same idempotency key" do
      payment = build_paid_payment
      service = -> { Refund.new(payment: payment, amount_cents: 500, idempotency_key: "same-refund").call }

      first = service.call
      assert_no_difference("PaymentRefund.count") { assert_equal first, service.call }
      assert_equal 500, payment.reload.refunded_amount_cents
    end

    test "rejects an amount above the remaining payment" do
      payment = build_paid_payment

      assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents + 1, idempotency_key: "too-high").call
      end
    end

    test "reserves a processing refund against concurrent requests" do
      payment = build_paid_payment
      payment.payment_refunds.create!(
        idempotency_key: "in-flight",
        amount_cents: 2_000,
        application_fee_amount_cents: payment.order.seller_order.platform_fee_refund_for(2_000)
      )

      assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: 501, idempotency_key: "concurrent").call
      end
    end
  end
end
