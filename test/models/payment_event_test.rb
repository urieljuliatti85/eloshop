require "test_helper"

class PaymentEventTest < ActiveSupport::TestCase
  test "invalid without gateway_event_id" do
    event = PaymentEvent.new(payment: payments(:one))
    assert_not event.valid?
    assert_includes event.errors[:gateway_event_id], "can't be blank"
  end

  test "invalid with duplicate gateway_event_id" do
    duplicate = PaymentEvent.new(payment: payments(:two), gateway_event_id: payment_events(:one).gateway_event_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:gateway_event_id], "has already been taken"
  end
end
