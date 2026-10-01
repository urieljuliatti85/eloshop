require "test_helper"

class SellerOrderTest < ActiveSupport::TestCase
  test "custom work is a made-to-order snapshot or a personalization, never a ready-made piece" do
    seller_order = seller_orders(:one)
    seller_order.order_items.update_all(production_time_snapshot: nil, personalizations: [])
    assert_not seller_order.reload.custom_work?

    seller_order.order_items.first.update!(production_time_snapshot: "7 a 10 dias úteis")
    assert seller_order.reload.custom_work?

    seller_order.order_items.update_all(production_time_snapshot: nil, personalizations: [ { "label" => "Nome", "value" => "Maria" } ])
    assert seller_order.reload.custom_work?
  end

  test "production start needs a confirmed, custom, unshipped order and cannot be repeated" do
    seller_order = seller_orders(:one)
    seller_order.order_items.first.update!(production_time_snapshot: "7 a 10 dias úteis")

    seller_order.update!(status: :pending)
    assert_not seller_order.production_start_applicable?
    assert_raises(SellerOrder::ProductionNotApplicable) { seller_order.start_production! }

    seller_order.update!(status: :confirmed)
    assert seller_order.production_start_applicable?
    seller_order.start_production!
    assert seller_order.production_started?
    assert_equal 1, seller_order.order.order_events.production_started.count

    assert_not seller_order.production_start_applicable?
    assert_raises(SellerOrder::ProductionNotApplicable) { seller_order.start_production! }
  end

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
