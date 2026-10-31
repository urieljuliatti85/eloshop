require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  # Minitest 6 não traz mais `stub`; troca o método só durante o bloco.
  def with_turnstile(result)
    original = Turnstile.method(:verify)
    Turnstile.define_singleton_method(:verify) { |*, **| result }
    yield
  ensure
    Turnstile.define_singleton_method(:verify, original)
  end

  def exhaust_account_email_budget
    Rails.cache.write("email_budget:account:#{Date.current.iso8601}", EmailAbuseProtection::DAILY_ACCOUNT_EMAIL_LIMIT, expires_in: 1.day)
  end

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "instruções de redefinição foram enviadas"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "instruções de redefinição foram enviadas"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "link de redefinição é inválido"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "Senha redefinida com sucesso"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "As senhas não coincidem"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end

  test "create is refused when the Turnstile refuses the token" do
    with_turnstile(:failed) { post passwords_path, params: { email_address: @user.email_address } }

    assert_redirected_to new_password_path
    assert_enqueued_emails 0
  end

  test "create sends nothing once the daily account e-mail limit is reached, with the same answer" do
    exhaust_account_email_budget

    post passwords_path, params: { email_address: @user.email_address }

    assert_redirected_to new_session_path
    assert_enqueued_emails 0
  end

  test "an unknown e-mail does not spend the daily budget" do
    post passwords_path, params: { email_address: "missing-user@example.com" }

    assert_nil Rails.cache.read("email_budget:account:#{Date.current.iso8601}")
  end
end
