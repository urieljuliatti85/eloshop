require "test_helper"

module Payments
  class RefundTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper
    def build_paid_payment(approved_at: 4.months.ago)
      sellers(:approved).update!(approved_at: approved_at)
      customer = customers(:one)
      address = addresses(:one)
      product = Product.create!(seller: sellers(:approved), name: "Reembolsável", sku: "REF-#{SecureRandom.hex(4)}", price_cents: 1_000, stock_quantity: 2, status: :active)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(recipient: checkout_recipient, cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
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

      events = payment.order.order_events.refund_processed
      assert_equal 2, events.count
      assert_equal "refunded", events.last.status
    end

    test "reverses the launch fee proportionally when the sale was made at 8%" do
      payment = build_paid_payment(approved_at: 1.day.ago)
      seller_order = payment.order.seller_order

      assert_equal 800, seller_order.platform_fee_rate_bps
      assert_equal 80, seller_order.platform_fee_cents

      Refund.new(payment: payment, amount_cents: 500, idempotency_key: "launch-partial").call
      assert_equal 16, payment.reload.application_fee_refunded_cents

      Refund.new(payment: payment, amount_cents: 2_000, idempotency_key: "launch-final").call
      assert_equal 80, payment.reload.application_fee_refunded_cents
      assert payment.refunded?
    end

    test "tells the buyer once when a refund is approved, never again on a replay or a rejection" do
      payment = build_paid_payment

      assert_enqueued_with(job: NotifyCustomerOfRefundJob) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "notify-once").call
      end

      assert_no_enqueued_jobs(only: NotifyCustomerOfRefundJob) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "notify-once").call
      end

      rejecting = Object.new
      rejecting.define_singleton_method(:refund) { |**| raise Gateways::MercadoPago::RequestRejected, "Mercado Pago respondeu 404" }
      assert_no_enqueued_jobs(only: NotifyCustomerOfRefundJob) do
        assert_raises(Gateways::MercadoPago::RequestRejected) do
          Refund.new(payment: payment, amount_cents: 500, idempotency_key: "rejected-no-mail", gateway: rejecting).call
        end
      end
    end

    test "tells the seller once when a refund is approved, with the total wording only when it empties the payment" do
      payment = build_paid_payment
      seller = payment.order.seller_order.seller
      refunds = -> { seller.notifications.order_refunded }

      assert_difference(-> { refunds.call.count }, 1) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "seller-partial").call
      end
      assert_equal "Reembolso parcial", refunds.call.order(:id).last.title

      assert_no_difference(-> { refunds.call.count }) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "seller-partial").call
      end

      assert_difference(-> { refunds.call.count }, 1) do
        Refund.new(payment: payment, amount_cents: payment.reload.remaining_refundable_cents, idempotency_key: "seller-total").call
      end
      last = refunds.call.order(:id).last
      assert_equal "Reembolso total", last.title
      assert_equal "/painel/orders/#{payment.order_id}", last.url
    end

    test "does not tell the seller while the refund is processing or after a rejection" do
      payment = build_paid_payment
      processing = Object.new
      processing.define_singleton_method(:refund) { |**| Gateways::RefundIntent.new(external_id: "r-p", status: "processing") }
      rejecting = Object.new
      rejecting.define_singleton_method(:refund) { |**| raise Gateways::MercadoPago::RequestRejected, "Mercado Pago respondeu 404" }

      assert_no_difference(-> { Notification.order_refunded.count }) do
        Refund.new(payment: payment, amount_cents: 300, idempotency_key: "seller-processing", gateway: processing).call
        assert_raises(Gateways::MercadoPago::RequestRejected) do
          Refund.new(payment: payment, amount_cents: 300, idempotency_key: "seller-rejected", gateway: rejecting).call
        end
      end
    end

    test "does not tell the buyer while the gateway still reports the refund as processing" do
      payment = build_paid_payment
      processing = Object.new
      processing.define_singleton_method(:refund) { |**| Gateways::RefundIntent.new(external_id: "r-1", status: "processing") }

      assert_no_enqueued_jobs(only: NotifyCustomerOfRefundJob) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "still-processing", gateway: processing).call
      end
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

    test "a definitive gateway rejection marks the refund failed and frees the amount for a new attempt" do
      payment = build_paid_payment
      rejecting = Object.new
      rejecting.define_singleton_method(:refund) { |**| raise Gateways::MercadoPago::RequestRejected, "Mercado Pago respondeu 404" }

      assert_raises(Gateways::MercadoPago::RequestRejected) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "rejected", gateway: rejecting).call
      end

      assert PaymentRefund.find_by!(idempotency_key: "rejected").failed?
      assert payment.reload.paid?
      assert_equal 0, payment.refunded_amount_cents

      retried = Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "second-try").call
      assert retried.approved?
    end

    test "reusing the key of a rejected attempt is refused instead of silently returning the failure" do
      payment = build_paid_payment
      rejecting = Object.new
      rejecting.define_singleton_method(:refund) { |**| raise Gateways::MercadoPago::InsufficientFunds, "sem saldo" }

      assert_raises(Gateways::MercadoPago::InsufficientFunds) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "attempt-1", gateway: rejecting).call
      end

      error = assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "attempt-1").call
      end
      assert_match "outra chave", error.message

      assert Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "attempt-2").call.approved?
    end

    test "a full refund reserves the amount before calling the gateway, so the seller cannot ship meanwhile" do
      payment = build_paid_payment
      shipment = payment.order.seller_order.shipment
      ship_error = nil
      gateway = Object.new
      gateway.define_singleton_method(:refund) do |**|
        begin
          shipment.reload.mark_shipped!
        rescue Shipment::InvalidStatusTransition => e
          ship_error = e
        end
        Gateways::RefundIntent.new(external_id: "mp-full", status: "approved")
      end

      Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "full-before-ship", gateway: gateway).call

      assert_match "reembolso integral em andamento", ship_error&.message.to_s
      assert shipment.reload.pending?
      assert payment.order.seller_order.reload.refunded?
    end

    test "records a refund made outside Mercado Pago through the same accounting, without calling the gateway" do
      payment = build_paid_payment
      admin = users(:one)
      seller = payment.order.seller_order.seller

      refund = nil
      assert_enqueued_with(job: NotifyCustomerOfRefundJob) do
        refund = Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "manual-1",
          manual_reference: "PIX E2E 1234", recorded_by: admin).call
      end

      assert refund.approved?
      assert refund.settled_by_manual?
      assert_equal "PIX E2E 1234", refund.manual_reference
      assert_equal admin, refund.recorded_by
      assert_nil refund.external_id
      assert payment.reload.refunded?
      assert payment.order.reload.refunded?
      assert_equal payment.application_fee_cents, payment.application_fee_refunded_cents
      assert_equal "Reembolso total", seller.notifications.order_refunded.order(:id).last.title
    end

    test "a manual refund needs the proof and who recorded it, and respects the remaining amount" do
      payment = build_paid_payment

      error = assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "manual-no-proof", manual_reference: " ", recorded_by: users(:one)).call
      end
      assert_match "comprovante", error.message
      assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "manual-no-admin", manual_reference: "PIX 99").call
      end
      assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents + 1, idempotency_key: "manual-too-much",
          manual_reference: "PIX 99", recorded_by: users(:one)).call
      end
      assert_equal 0, payment.payment_refunds.count
    end

    test "the database refuses a manual refund without proof even if the model is bypassed" do
      payment = build_paid_payment

      assert_raises(ActiveRecord::StatementInvalid) do
        PaymentRefund.insert_all!([ { payment_id: payment.id, idempotency_key: "raw-manual", amount_cents: 100,
          application_fee_amount_cents: 0, settlement: "manual", status: "approved" } ])
      end
    end

    test "a manual refund still asks for the chargeback acknowledgement" do
      payment = build_paid_payment
      ProcessWebhook.new(event_id: "cb-manual-#{SecureRandom.hex(3)}", external_id: payment.external_id, status: "charged_back").call

      assert_raises(Refund::ChargebackReported) do
        Refund.new(payment: payment, amount_cents: 500, idempotency_key: "manual-cb", manual_reference: "PIX 1", recorded_by: users(:one)).call
      end
      assert Refund.new(payment: payment, amount_cents: 500, idempotency_key: "manual-cb-ack", manual_reference: "PIX 1",
        recorded_by: users(:one), chargeback_acknowledged: true).call.approved?
    end

    test "refuses to refund a charged-back payment unless the admin acknowledges the dispute" do
      payment = build_paid_payment
      ProcessWebhook.new(event_id: "cb-#{SecureRandom.hex(4)}", external_id: payment.external_id, status: "charged_back").call
      assert payment.reload.paid?, "o chargeback só sinaliza; o pagamento segue paid"

      assert_no_difference("PaymentRefund.count") do
        assert_raises(Refund::ChargebackReported) do
          Refund.new(payment: payment, amount_cents: 500, idempotency_key: "cb-blocked").call
        end
      end

      refund = Refund.new(payment: payment, amount_cents: 500, idempotency_key: "cb-acknowledged", chargeback_acknowledged: true).call
      assert refund.approved?
    end

    test "a payment without chargeback refunds without any acknowledgement" do
      payment = build_paid_payment
      ProcessWebhook.new(event_id: "dec-#{SecureRandom.hex(4)}", external_id: payment.external_id, status: "declined").call

      assert_not payment.reload.chargeback_reported?
      assert Refund.new(payment: payment, amount_cents: 500, idempotency_key: "no-cb").call.approved?
    end

    test "an ambiguous gateway failure keeps the refund processing and the amount reserved" do
      payment = build_paid_payment
      flaky = Object.new
      flaky.define_singleton_method(:refund) { |**| raise Gateways::MercadoPago::RequestFailed, "Mercado Pago respondeu 500" }

      assert_raises(Gateways::MercadoPago::RequestFailed) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "ambiguous", gateway: flaky).call
      end

      assert PaymentRefund.find_by!(idempotency_key: "ambiguous").processing?
      assert_raises(Refund::InvalidRefund) do
        Refund.new(payment: payment, amount_cents: payment.amount_cents, idempotency_key: "blocked").call
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
