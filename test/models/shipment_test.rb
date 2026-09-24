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

  test "marks a shipped order as delivered and records the time" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!

    assert_changes -> { @shipment.reload.status }, from: "shipped", to: "delivered" do
      @shipment.mark_delivered!
    end

    assert_in_delta Time.current, @shipment.delivered_at, 1.second
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

  test "the seller can still officially confirm delivery after the customer's report" do
    @seller_order.update!(status: :confirmed)
    @shipment.mark_shipped!
    @shipment.report_delivered_by_customer!

    assert_changes -> { @shipment.reload.status }, from: "shipped", to: "delivered" do
      @shipment.mark_delivered!
    end
  end
end
