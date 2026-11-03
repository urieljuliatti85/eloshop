require "test_helper"

module Payments
  class ReconcileRefundsTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @payment = build_paid_payment
    end

    test "applies an approved remote refund that the original call never confirmed" do
      refund = processing_refund(amount_cents: @payment.amount_cents, external_id: "mp-77", age: 15.minutes)

      assert_enqueued_with(job: NotifyCustomerOfRefundJob) do
        reconcile(remote(external_id: "mp-77", status: "approved", amount_cents: @payment.amount_cents))
      end

      assert refund.reload.approved?
      assert @payment.reload.refunded?
      assert @payment.order.reload.refunded?
      assert_equal @payment.order.seller_order.platform_fee_cents, @payment.application_fee_refunded_cents
    end

    test "adopts the remote refund of the same amount when the response was lost" do
      refund = processing_refund(amount_cents: 500, age: 15.minutes)

      reconcile(remote(external_id: "mp-lost", status: "approved", amount_cents: 500))

      assert refund.reload.approved?
      assert_equal "mp-lost", refund.external_id
      assert_equal 500, @payment.reload.refunded_amount_cents
    end

    test "does not adopt a remote refund already recognized by another attempt" do
      @payment.payment_refunds.create!(idempotency_key: "known", amount_cents: 500, application_fee_amount_cents: 0,
        external_id: "mp-known", status: "failed")
      refund = processing_refund(amount_cents: 500, age: 15.minutes)

      reconcile(remote(external_id: "mp-known", status: "approved", amount_cents: 500))

      assert refund.reload.processing?
    end

    test "records the remote id and keeps waiting while the refund is still in contingency" do
      refund = processing_refund(amount_cents: 500, age: 15.minutes)

      assert_no_enqueued_jobs(only: NotifyCustomerOfRefundJob) do
        reconcile(remote(external_id: "mp-pix", status: "processing", amount_cents: 500))
      end

      assert refund.reload.processing?
      assert_equal "mp-pix", refund.external_id
    end

    test "a rejected remote refund frees the reserved amount for a new attempt" do
      refund = processing_refund(amount_cents: @payment.amount_cents, external_id: "mp-no", age: 15.minutes)

      reconcile(remote(external_id: "mp-no", status: "failed", amount_cents: @payment.amount_cents))

      assert refund.reload.failed?
      assert Refund.new(payment: @payment, amount_cents: @payment.amount_cents, idempotency_key: "new-attempt").call.approved?
    end

    test "gives up on a lost attempt that never appeared on the gateway after an hour" do
      recent = processing_refund(amount_cents: 300, age: 30.minutes)
      old = processing_refund(amount_cents: 400, age: 2.hours)

      reconcile

      assert recent.reload.processing?
      assert old.reload.failed?
    end

    test "never gives up on an attempt the gateway already acknowledged" do
      refund = processing_refund(amount_cents: 500, external_id: "mp-acked", age: 2.hours)

      reconcile

      assert refund.reload.processing?
    end

    test "leaves recent attempts to the original call" do
      refund = processing_refund(amount_cents: 500, external_id: "mp-fresh", age: 2.minutes)

      reconcile(remote(external_id: "mp-fresh", status: "approved", amount_cents: 500))

      assert refund.reload.processing?
    end

    test "a gateway failure on one refund does not stop the others" do
      broken = processing_refund(amount_cents: 300, external_id: "mp-broken", age: 15.minutes)
      other_payment = build_paid_payment
      other = other_payment.payment_refunds.create!(idempotency_key: "other", amount_cents: 200,
        application_fee_amount_cents: 0, external_id: "mp-other")
      other.update_columns(created_at: 15.minutes.ago)

      gateway = stub_gateway([])
      gateway.define_singleton_method(:refunds_for) do |payment:|
        raise Gateways::MercadoPago::RequestFailed, "Mercado Pago respondeu 500" if payment.id == broken.payment_id

        [ Gateways::RemoteRefund.new(external_id: "mp-other", status: "approved", amount_cents: 200) ]
      end
      ReconcileRefunds.new(gateway: gateway).call

      assert broken.reload.processing?
      assert other.reload.approved?
    end

    private

    def reconcile(*remote_refunds)
      ReconcileRefunds.new(gateway: stub_gateway(remote_refunds)).call
    end

    def remote(external_id:, status:, amount_cents:)
      Gateways::RemoteRefund.new(external_id: external_id, status: status, amount_cents: amount_cents)
    end

    def stub_gateway(remote_refunds)
      Object.new.tap do |gateway|
        gateway.define_singleton_method(:name) { "fake" }
        gateway.define_singleton_method(:refunds_for) { |payment:| remote_refunds }
      end
    end

    def processing_refund(amount_cents:, age:, external_id: nil)
      refund = @payment.payment_refunds.create!(
        idempotency_key: "attempt-#{SecureRandom.hex(4)}",
        amount_cents: amount_cents,
        application_fee_amount_cents: @payment.order.seller_order.platform_fee_refund_for(amount_cents),
        external_id: external_id
      )
      refund.update_columns(created_at: age.ago)
      refund
    end

    def build_paid_payment
      customer = customers(:one)
      product = Product.create!(seller: sellers(:approved), name: "Reconciliável #{SecureRandom.hex(4)}", sku: "REC-#{SecureRandom.hex(4)}", price_cents: 1_000, stock_quantity: 2, status: :active)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: addresses(:one), idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order).call
      ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "approved").call
      payment.reload
    end
  end
end
