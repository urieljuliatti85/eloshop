require "test_helper"

class NotifyCustomerOfRefundJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "delivers the refund e-mail to the buyer" do
    customer = Customer.create!(name: "Maria", email: "refund-#{SecureRandom.hex(4)}@example.com", password: "password123")
    order = orders(:one)
    order.update!(customer: customer)
    payment = order.payments.create!(
      gateway: "fake", status: :refunded, external_id: "fake-job", amount_cents: order.total_cents,
      application_fee_cents: 0, refunded_amount_cents: order.total_cents
    )
    refund = payment.payment_refunds.create!(idempotency_key: "job-1", amount_cents: order.total_cents, application_fee_amount_cents: 0, status: :approved)

    assert_emails 1 do
      NotifyCustomerOfRefundJob.perform_now(refund)
    end

    assert_equal [ customer.email ], ActionMailer::Base.deliveries.last.to
  end
end
