require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  setup do
    @seller_order = seller_orders(:one)
    @shipment = Shipment.create!(
      seller_order: @seller_order,
      carrier: "Entrega EloShop",
      service: "Entrega padrão",
      shipping_cents: 1_500,
      estimated_days: 5
    )
  end

  test "marks a confirmed order as shipped and records the time" do
    @seller_order.update!(status: :confirmed)

    assert_changes -> { @shipment.reload.status }, from: "pending", to: "shipped" do
      @shipment.mark_shipped!
    end

    assert_in_delta Time.current, @shipment.shipped_at, 1.second
  end

  test "awaits dispatch only while paid, pending and not a local pickup" do
    assert_not @shipment.awaiting_dispatch?, "unpaid order"

    @seller_order.update!(status: :confirmed)
    assert @shipment.awaiting_dispatch?

    @shipment.update!(service: Shipping::Quote::LOCAL_PICKUP_SERVICE)
    assert_not @shipment.awaiting_dispatch?, "local pickup"

    @shipment.update!(service: "PAC")
    @shipment.mark_shipped!
    assert_not @shipment.awaiting_dispatch?, "already shipped"
  end

  test "normalizes the tracking code typed by the atelier" do
    @seller_order.update!(status: :confirmed)

    @shipment.mark_shipped!(tracking_code: " aa 123 456 789 br ")

    assert_equal "AA123456789BR", @shipment.reload.tracking_code
  end

  test "keeps the tracking code empty when none is given" do
    @seller_order.update!(status: :confirmed)

    @shipment.mark_shipped!(tracking_code: "  ")

    assert_nil @shipment.reload.tracking_code
  end

  test "rejects a tracking code with characters no carrier uses" do
    @seller_order.update!(status: :confirmed)

    error = assert_raises(Shipment::InvalidTrackingCode) do
      @shipment.mark_shipped!(tracking_code: "<script>AA1</script>")
    end

    assert_equal Shipment::INVALID_TRACKING_CODE_MESSAGE, error.message
    assert @shipment.reload.pending?
  end

  test "rejects a tracking code already used by another shipment, with the same message as a malformed one" do
    @seller_order.update!(status: :confirmed)
    other_seller_order = seller_orders(:two)
    other_seller_order.update!(status: :confirmed)
    Shipment.create!(seller_order: other_seller_order, carrier: "Correios", service: "PAC",
      shipping_cents: 1_500, estimated_days: 5, tracking_code: "AA123456789BR")

    error = assert_raises(Shipment::InvalidTrackingCode) do
      @shipment.mark_shipped!(tracking_code: "aa123456789br")
    end

    assert_equal Shipment::INVALID_TRACKING_CODE_MESSAGE, error.message
    assert @shipment.reload.pending?
    assert_nil @shipment.shipped_at
  end

  test "marks a shipped order as delivered and records the time" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!

    assert_changes -> { @shipment.reload.status }, from: "shipped", to: "delivered" do
      @shipment.mark_delivered!
    end

    assert_in_delta Time.current, @shipment.delivered_at, 1.second
  end

  test "refuses to ship while a full refund is still processing, and allows it again once the attempt fails" do
    payment = paid_payment_for(@seller_order)
    refund = payment.payment_refunds.create!(idempotency_key: "full-in-flight", amount_cents: payment.amount_cents, application_fee_amount_cents: 0)

    error = assert_raises(Shipment::InvalidStatusTransition) { @shipment.mark_shipped! }
    assert_match "reembolso integral em andamento", error.message
    assert_predicate @shipment.reload, :pending?

    refund.update!(status: "failed")
    @shipment.mark_shipped!
    assert_predicate @shipment.reload, :shipped?
  end

  test "refuses to ship while a withdrawal is open, and allows it again once the request is closed" do
    @seller_order.update!(status: :confirmed)
    return_request = ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :withdrawal).call.return_request

    error = assert_raises(Shipment::InvalidStatusTransition) { @shipment.mark_shipped! }
    assert_match "desistir da compra (#{return_request.protocol})", error.message
    assert_predicate @shipment.reload, :pending?

    return_request.record_update!(author: users(:one), new_status: "closed")
    @shipment.mark_shipped!
    assert_predicate @shipment.reload, :shipped?
  end

  test "other open requests do not block shipping" do
    @seller_order.update!(status: :confirmed)
    ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :delivery_issue).call

    @shipment.mark_shipped!
    assert_predicate @shipment.reload, :shipped?
  end

  test "a withdrawal opened after shipping does not block confirming delivery" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!
    ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :withdrawal).call

    @shipment.mark_delivered!
    assert_predicate @shipment.reload, :delivered?
  end

  test "a partial refund in progress does not block shipping" do
    payment = paid_payment_for(@seller_order)
    payment.payment_refunds.create!(idempotency_key: "partial-in-flight", amount_cents: payment.amount_cents - 1, application_fee_amount_cents: 0)

    @shipment.mark_shipped!
    assert_predicate @shipment.reload, :shipped?
  end

  test "a full refund in progress does not block confirming delivery of a shipped order" do
    payment = paid_payment_for(@seller_order)
    @shipment.mark_shipped!
    payment.payment_refunds.create!(idempotency_key: "after-shipping", amount_cents: payment.amount_cents, application_fee_amount_cents: 0)

    @shipment.mark_delivered!
    assert_predicate @shipment.reload, :delivered?
  end

  test "does not advance delivery before payment confirmation" do
    error = assert_raises(Shipment::InvalidStatusTransition) { @shipment.mark_shipped! }

    assert_equal "o pagamento precisa estar confirmado antes de atualizar a entrega", error.message
    assert_predicate @shipment.reload, :pending?
  end

  test "does not skip the shipped step" do
    @seller_order.update!(status: :confirmed)

    assert_raises(Shipment::InvalidStatusTransition) { @shipment.mark_delivered! }
    assert_predicate @shipment.reload, :pending?
  end

  # Sinal do cliente, deliberadamente separado do status oficial: não muda
  # `status` nem pode ser confundido com `mark_delivered!` — só o vendedor
  # fecha a entrega de fato.
  test "records the customer's delivery report without changing the official status" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!

    assert_no_changes -> { @shipment.reload.status } do
      @shipment.report_delivered_by_customer!
    end

    assert_in_delta Time.current, @shipment.customer_reported_delivered_at, 1.second
    assert_predicate @shipment.reload, :shipped?
  end

  test "does not accept the customer's delivery report before the shipment is marked as shipped" do
    @seller_order.update!(status: :confirmed)

    error = assert_raises(Shipment::InvalidStatusTransition) { @shipment.report_delivered_by_customer! }

    assert_equal "o envio precisa estar marcado como enviado", error.message
    assert_nil @shipment.reload.customer_reported_delivered_at
  end

  # O cliente pode clicar de novo: a data do primeiro aviso fica, e o retorno
  # `false` impede o controller de repetir e-mail e notificação ao artesão.
  test "a repeated customer delivery report keeps the first date and returns false" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!

    assert @shipment.report_delivered_by_customer!
    first_report = @shipment.reload.customer_reported_delivered_at

    travel 1.hour do
      assert_not @shipment.report_delivered_by_customer!
    end
    assert_equal first_report, @shipment.reload.customer_reported_delivered_at
  end

  test "the seller can still officially confirm delivery after the customer's report" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!
    @shipment.report_delivered_by_customer!

    assert_changes -> { @shipment.reload.status }, from: "shipped", to: "delivered" do
      @shipment.mark_delivered!
    end
  end

  private

  def paid_payment_for(seller_order)
    seller_order.update!(status: :confirmed)
    payment = payments(:one)
    payment.update!(status: "paid")
    payment
  end
end
