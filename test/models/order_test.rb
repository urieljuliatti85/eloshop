require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "invalid with duplicate idempotency_key" do
    duplicate = Order.new(orders(:one).attributes.except("id").merge("idempotency_key" => orders(:two).idempotency_key))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key], "has already been taken"
  end

  test "invalid without shipping_address_snapshot" do
    order = Order.new(orders(:one).attributes.except("id", "shipping_address_snapshot", "idempotency_key"))
    assert_not order.valid?
    assert_includes order.errors[:shipping_address_snapshot], "can't be blank"
  end

  test "invalid with negative totals" do
    order = Order.new(orders(:one).attributes.except("id", "idempotency_key").merge("total_cents" => -1))
    assert_not order.valid?
    assert_includes order.errors[:total_cents], "must be greater than or equal to 0"
  end
end
