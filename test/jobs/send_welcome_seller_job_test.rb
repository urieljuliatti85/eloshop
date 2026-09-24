require "test_helper"

class SendWelcomeSellerJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "delivers the welcome email to the given recipient" do
    seller = sellers(:approved)

    assert_emails 1 do
      SendWelcomeSellerJob.perform_now(seller, "dono@example.com")
    end
  end
end
