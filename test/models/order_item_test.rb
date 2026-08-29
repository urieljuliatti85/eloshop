require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  test "subtotal_cents is unit_price_cents times quantity" do
    item = order_items(:two)
    assert_equal 9980, item.subtotal_cents
  end

  test "invalid without product_name or sku" do
    item = OrderItem.new(order: orders(:one), product: products(:one), unit_price_cents: 100, quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product_name], "can't be blank"
    assert_includes item.errors[:sku], "can't be blank"
  end

  test "invalid with quantity zero" do
    item = OrderItem.new(order: orders(:one), product: products(:one), product_name: "X", sku: "X", unit_price_cents: 100, quantity: 0)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end
end
