require "test_helper"

class CustomerSessionTest < ActiveSupport::TestCase
  test "active includes a recently active session" do
    session = customers(:one).customer_sessions.create!

    assert_includes CustomerSession.active, session
  end

  test "active excludes a session past the inactivity timeout" do
    session = customers(:one).customer_sessions.create!
    session.update_column(:updated_at, CustomerSession::INACTIVITY_TIMEOUT.ago - 1.minute)

    assert_not_includes CustomerSession.active, session
  end
end
