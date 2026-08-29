require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to customer login" do
    get new_order_payment_path(orders(:one))
    assert_redirected_to new_customer_session_path
  end

  test "a customer cannot access another customer's order payment" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:two))

    assert_response :not_found
  end

  test "an authenticated customer can view their own order's payment page" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:one))

    assert_response :success
  end

  test "the payment page never renders a card number or CVV field" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:one))

    assert_no_match(/name="card_number"|name="cvv"/, response.body)
  end

  private

  def sign_in_customer(customer)
    get new_customer_session_path
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end
end
