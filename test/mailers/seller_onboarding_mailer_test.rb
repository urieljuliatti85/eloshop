require "test_helper"

class SellerOnboardingMailerTest < ActionMailer::TestCase
  test "tells the platform which seller waits for approval and links to the admin" do
    seller = sellers(:pending)

    mail = SellerOnboardingMailer.awaiting_approval(seller)

    assert_equal [ "contato@eloshop.shop" ], mail.to
    assert_match seller.name, mail.subject
    assert_match "KYC", mail.body.encoded
    assert_match "/admin/sellers/#{seller.slug}", mail.body.encoded
  end
end
