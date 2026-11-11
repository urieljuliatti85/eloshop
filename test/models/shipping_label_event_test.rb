require "test_helper"

class ShippingLabelEventTest < ActiveSupport::TestCase
  include ShippingLabelTestHelper

  setup do
    prepare_label_scenario
    @label = build_label(status: :purchased, purchased_at: Time.current)
  end

  test "records only the fields it uses, once per order and event" do
    body = { event: "order.posted", data: { id: "sf-order-1", status: "posted", tracking: "AA123456789BR", user_id: "u1", tags: [ { name: "x" } ] } }.to_json

    event = ShippingLabelEvent.record(seller: @seller, body: body)

    assert_equal [ "order.posted", "posted", "AA123456789BR" ], [ event.event, event.status, event.tracking_code ]
    assert_equal @label, event.shipping_label
    assert_nil ShippingLabelEvent.record(seller: @seller, body: body)
    assert_equal 1, ShippingLabelEvent.count
  end

  test "another seller cannot reach this seller's label by its id" do
    other = sellers(:other)
    body = { event: "order.posted", data: { id: "sf-order-1", status: "posted" } }.to_json

    assert_nil ShippingLabelEvent.record(seller: other, body: body)
  end

  test "malformed bodies are ignored" do
    assert_nil ShippingLabelEvent.record(seller: @seller, body: "not json")
    assert_nil ShippingLabelEvent.record(seller: @seller, body: { event: "order.posted" }.to_json)
    assert_nil ShippingLabelEvent.record(seller: @seller, body: [ 1 ].to_json)
  end
end
