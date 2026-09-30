require "test_helper"

class FraudAlertMailerTest < ActionMailer::TestCase
  test "goes to the contact address with the seller and a link to the admin" do
    alert = FraudAlert.create!(seller: sellers(:approved), rule: "unverified_account", detected_at: Time.current)

    mail = FraudAlertMailer.new_alerts([ alert.id ])

    assert_equal [ "contato@eloshop.shop" ], mail.to
    assert_match "1 alerta(s)", mail.subject
    assert_match sellers(:approved).name, mail.body.encoded
    assert_match "/admin/sellers/#{sellers(:approved).slug}", mail.body.encoded
  end
end
