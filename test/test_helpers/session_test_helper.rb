module SessionTestHelper
  def sign_in_as(user)
    if user.seller?
      SellerTermsAcceptance.find_or_create_by!(user: user, terms_version: SellerTerms.version) do |acceptance|
        acceptance.assign_attributes(
          seller: user.seller,
          terms_text: SellerTerms.text,
          terms_digest: Digest::SHA256.hexdigest(SellerTerms.text),
          accepted_at: Time.current,
          ip_address: "127.0.0.1"
        )
      end
    end
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
