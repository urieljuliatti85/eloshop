require "test_helper"

class CouponTest < ActiveSupport::TestCase
  def build_coupon(**attrs)
    Coupon.new({
      code: "PROMO#{SecureRandom.hex(4)}",
      discount_type: "percentage",
      percentage: 10
    }.merge(attrs))
  end

  test "valid with a percentage discount" do
    assert build_coupon.valid?
  end

  test "valid with a fixed discount" do
    assert build_coupon(discount_type: "fixed", percentage: nil, amount_cents: 500).valid?
  end

  test "invalid without a code" do
    coupon = build_coupon(code: nil)
    assert_not coupon.valid?
    assert_includes coupon.errors[:code], "can't be blank"
  end

  test "invalid with a duplicate code" do
    build_coupon(code: "DUPLICADO").save!
    duplicate = build_coupon(code: "duplicado")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "upcases the code before saving" do
    coupon = build_coupon(code: "verao10")
    coupon.save!
    assert_equal "VERAO10", coupon.code
  end

  test "invalid percentage coupon without a percentage" do
    coupon = build_coupon(percentage: nil)
    assert_not coupon.valid?
    assert_includes coupon.errors[:percentage], "can't be blank"
  end

  test "invalid percentage coupon above 100" do
    coupon = build_coupon(percentage: 101)
    assert_not coupon.valid?
  end

  test "invalid percentage coupon with an amount_cents set" do
    coupon = build_coupon(amount_cents: 500)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_cents], "must be blank"
  end

  test "invalid fixed coupon without amount_cents" do
    coupon = build_coupon(discount_type: "fixed", percentage: nil)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_cents], "can't be blank"
  end

  test "valid_for? is false when inactive" do
    coupon = build_coupon(active: false)
    assert_not coupon.valid_for?(10_000)
  end

  test "valid_for? is false when expired" do
    coupon = build_coupon(expires_at: 1.day.ago)
    assert_not coupon.valid_for?(10_000)
  end

  test "valid_for? is false before starts_at" do
    coupon = build_coupon(starts_at: 1.day.from_now)
    assert_not coupon.valid_for?(10_000)
  end

  test "valid_for? is false when uses are exhausted" do
    coupon = build_coupon(max_uses: 1, uses_count: 1)
    assert_not coupon.valid_for?(10_000)
  end

  test "valid_for? is false when subtotal is below the minimum" do
    coupon = build_coupon(minimum_subtotal_cents: 20_000)
    assert_not coupon.valid_for?(10_000)
  end

  test "valid_for? is true when every condition is met" do
    coupon = build_coupon(minimum_subtotal_cents: 5_000, max_uses: 5, uses_count: 2, starts_at: 1.day.ago, expires_at: 1.day.from_now)
    assert coupon.valid_for?(10_000)
  end

  test "discount_cents_for computes a percentage discount" do
    coupon = build_coupon(percentage: 10)
    assert_equal 1_000, coupon.discount_cents_for(10_000)
  end

  test "discount_cents_for computes a fixed discount" do
    coupon = build_coupon(discount_type: "fixed", percentage: nil, amount_cents: 3_000)
    assert_equal 3_000, coupon.discount_cents_for(10_000)
  end

  test "discount_cents_for never exceeds the subtotal" do
    coupon = build_coupon(discount_type: "fixed", percentage: nil, amount_cents: 50_000)
    assert_equal 10_000, coupon.discount_cents_for(10_000)
  end
end
