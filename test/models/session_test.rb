require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "active includes a recently active session" do
    session = users(:one).sessions.create!

    assert_includes Session.active, session
  end

  test "active excludes a session past the inactivity timeout" do
    session = users(:one).sessions.create!
    session.update_column(:updated_at, Session::INACTIVITY_TIMEOUT.ago - 1.minute)

    assert_not_includes Session.active, session
  end
end
