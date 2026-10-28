require "test_helper"

class NotifySellerOfApprovalJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "during pre-registration tells the seller the store is ready and sales open later" do
    PlatformSetting.instance.update!(sales_opened_at: nil)

    assert_emails 1 do
      NotifySellerOfApprovalJob.perform_now(sellers(:approved))
    end

    body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    expected = PlatformSetting.pre_launch_notice(ready: sellers(:approved).setup_steps.values.all?)
    assert_match expected, body
    assert_match "/artesaos/#{sellers(:approved).slug}", body
  end

  test "after sales opened tells the seller the catalog is on sale" do
    assert_emails 1 do
      NotifySellerOfApprovalJob.perform_now(sellers(:approved))
    end

    body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    assert_no_match PlatformSetting::SALES_OPENING_PROMISE, body
    assert_match "podem ser compradas", body
  end
end
