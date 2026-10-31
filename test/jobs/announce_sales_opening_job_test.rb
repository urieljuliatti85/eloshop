require "test_helper"

class AnnounceSalesOpeningJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "enqueues one notification per seller listed in the store only" do
    sellers(:approved).hide!
    sellers(:pending).showcase!
    expected = Seller.publicly_listed.count

    assert_includes Seller.publicly_listed, sellers(:pending)
    assert_not_includes Seller.publicly_listed, sellers(:approved)
    assert_enqueued_jobs expected, only: NotifySellerOfSalesOpeningJob do
      AnnounceSalesOpeningJob.perform_now
    end
  end

  test "a showcased seller without approval is asked to connect Mercado Pago" do
    seller = sellers(:pending)
    seller.showcase!
    user = User.create!(email_address: "vitrine-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller)

    assert_emails 1 do
      NotifySellerOfSalesOpeningJob.perform_now(seller)
    end

    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, user.email_address
    assert_match "Mercado Pago", email.subject
    assert_match "/painel/primeiros-passos/mercado-pago", email.text_part.body.to_s
    assert_match "/artesaos/#{seller.slug}", email.text_part.body.to_s
    assert_no_match "divulgar", email.text_part.body.to_s
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
