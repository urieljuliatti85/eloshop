require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
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

  test "signing up creates a customer, starts a session, and associates the current cart" do
    get products_path # garante que um carrinho de sessão já exista via cookie

    assert_difference("Customer.count", 1) do
      assert_enqueued_with(job: SendWelcomeCustomerJob) do
        post customers_path, params: {
          customer: {
            name: "Nova Cliente",
            email: "nova@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    customer = Customer.find_by(email: "nova@example.com")
    assert_redirected_to root_path
    assert_equal customer, customer.customer_sessions.last.customer
    assert_equal customer, Cart.order(:created_at).last.customer
  end

  test "does not sign up with a duplicate email" do
    assert_no_difference("Customer.count") do
      post customers_path, params: {
        customer: {
          name: "Duplicado",
          email: customers(:one).email,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  SIGNUP = { customer: { name: "Nova", email: "nova@example.com", password: "password123", password_confirmation: "password123" } }.freeze

  test "signing up is refused when the Turnstile refuses the token" do
    with_turnstile(:failed) do
      assert_no_difference("Customer.count") { post customers_path, params: SIGNUP }
    end

    assert_response :unprocessable_entity
    assert_match "confirmar que você é uma pessoa", response.body
  end

  test "signing up still works but sends no welcome e-mail once the daily account e-mail limit is reached" do
    exhaust_account_email_budget

    assert_difference("Customer.count", 1) { post customers_path, params: SIGNUP }
    assert_no_enqueued_jobs only: SendWelcomeCustomerJob
  end

  test "signing up tells the customer to check the spam folder when the welcome e-mail was sent" do
    post customers_path, params: SIGNUP
    assert_match "caixa de spam", flash[:notice]
  end

  test "signing up does not mention the welcome e-mail once the daily limit is reached" do
    exhaust_account_email_budget
    post customers_path, params: SIGNUP
    assert_no_match "spam", flash[:notice]
  end
end
