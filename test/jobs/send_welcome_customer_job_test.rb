require "test_helper"

class SendWelcomeCustomerJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "delivers the welcome email to the customer" do
    customer = customers(:one)

    assert_emails 1 do
      SendWelcomeCustomerJob.perform_now(customer)
    end
  end
end
