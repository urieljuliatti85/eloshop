require "test_helper"

class AnnounceSalesOpeningJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "enqueues one notification per approved and visible seller only" do
    sellers(:approved).hide!
    expected = Seller.approved.visible.count

    assert_operator Seller.where.not(status: :approved).count, :>, 0
    assert_enqueued_jobs expected, only: NotifySellerOfSalesOpeningJob do
      AnnounceSalesOpeningJob.perform_now
    end
  end

  test "the seller notification asks to share the atelier page" do
    seller = sellers(:approved)
    recipient = seller.users.order(:created_at).first.email_address

    assert_emails 1 do
      NotifySellerOfSalesOpeningJob.perform_now(seller)
    end

    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, recipient
    assert_match "/artesaos/#{seller.slug}", email.text_part.body.to_s
    assert_match "divulgar", email.text_part.body.to_s
  end
end
