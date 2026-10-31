require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  test "accepts a token that is old enough" do
    token = travel_to(5.seconds.ago) { ContactMessage.issue_token }

    assert_nil ContactMessage.rejection_for(token: token, honeypot: nil)
    assert_nil ContactMessage.rejection_for(token: token, honeypot: "")
  end

  test "rejects a token that is too fresh, missing, forged or expired" do
    assert_equal :token, ContactMessage.rejection_for(token: ContactMessage.issue_token, honeypot: nil)
    assert_equal :token, ContactMessage.rejection_for(token: nil, honeypot: nil)
    assert_equal :token, ContactMessage.rejection_for(token: "forjado", honeypot: nil)
    expired = travel_to(2.days.ago) { ContactMessage.issue_token }
    assert_equal :token, ContactMessage.rejection_for(token: expired, honeypot: nil)
  end

  test "a filled decoy wins over a valid token" do
    token = travel_to(5.seconds.ago) { ContactMessage.issue_token }

    assert_equal :honeypot, ContactMessage.rejection_for(token: token, honeypot: "x")
  end
end
