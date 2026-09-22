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
end
