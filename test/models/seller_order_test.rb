require "test_helper"

class SellerOrderTest < ActiveSupport::TestCase
  test "calculates fifteen percent after discounts and excludes shipping" do
    fee = SellerOrder.platform_fee_cents_for(subtotal_cents: 10_000, discount_cents: 1_000)

    assert_equal 1_350, fee
  end

  test "rounds a fractional cent half up" do
    assert_equal 1_349, SellerOrder.platform_fee_cents_for(subtotal_cents: 8_990, discount_cents: 0)
  end

  test "calculates cumulative proportional fee reversal without rounding drift" do
    seller_order = seller_orders(:one)

    first_fee = seller_order.platform_fee_refund_for(1_000)
    seller_order.refunded_amount_cents = 1_000
    seller_order.platform_fee_refunded_cents = first_fee
    second_fee = seller_order.platform_fee_refund_for(seller_order.remaining_refundable_cents)

    assert_equal seller_order.platform_fee_cents, first_fee + second_fee
  end

  test "accounts for concurrent reservations when splitting a rounding cent" do
    seller_order = seller_orders(:one)
    first_fee = seller_order.platform_fee_refund_for(5_245)
    second_fee = seller_order.platform_fee_refund_for(
      5_245,
      reserved_amount_cents: 5_245,
      reserved_fee_cents: first_fee
    )

    assert_equal 675, first_fee
    assert_equal 674, second_fee
    assert_equal seller_order.platform_fee_cents, first_fee + second_fee
  end
end
