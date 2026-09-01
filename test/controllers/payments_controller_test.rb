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

  test "status returns the latest payment without creating another attempt" do
    sign_in_customer(customers(:one))
    payment = payments(:one)

    get status_order_payment_path(orders(:one))

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal payment.id, orders(:one).payments.order(:created_at).last.id
    assert_equal 1, orders(:one).payments.count
  end

  test "status reports an expired pix without creating a replacement charge" do
    sign_in_customer(customers(:one))
    payment = payments(:one)
    payment.update!(pix_qr_code: "pix-code", expires_at: 1.minute.ago)

    assert_no_difference("Payment.count") do
      get status_order_payment_path(orders(:one))
    end

    assert_response :success
    assert_match(/recusado ou expirado/, response.body)
    assert_no_match(/data-controller="payment-status"/, response.body)
  end

  test "a customer cannot poll another customer's payment" do
    sign_in_customer(customers(:one))

    get status_order_payment_path(orders(:two))

    assert_response :not_found
  end

  private

  def sign_in_customer(customer)
    get new_customer_session_path
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end
end
