require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "invalid without gateway" do
    payment = Payment.new(order: orders(:one), external_id: "x", amount_cents: 100)
    assert_not payment.valid?
    assert_includes payment.errors[:gateway], "can't be blank"
  end

  test "invalid without external_id" do
    payment = Payment.new(order: orders(:one), gateway: "fake", amount_cents: 100)
    assert_not payment.valid?
    assert_includes payment.errors[:external_id], "can't be blank"
  end

  test "invalid with negative amount_cents" do
    payment = Payment.new(order: orders(:one), gateway: "fake", external_id: "x", amount_cents: -1)
    assert_not payment.valid?
    assert_includes payment.errors[:amount_cents], "must be greater than or equal to 0"
  end

  test "defaults to pending status" do
    payment = Payment.create!(order: orders(:one), gateway: "fake", external_id: SecureRandom.hex(10), amount_cents: 100)
    assert payment.pending?
  end
end
