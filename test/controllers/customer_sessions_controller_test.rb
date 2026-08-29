require "test_helper"

class CustomerSessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @customer = customers(:one) }

  test "logs in with valid credentials and associates the current cart" do
    get products_path # garante que um carrinho de sessão já exista via cookie

    post customer_session_path, params: { email: @customer.email, password: "password123" }

    assert_redirected_to root_path
    assert cookies[:customer_session_id]
    assert_equal @customer, Cart.order(:created_at).last.customer
  end

  test "does not log in with invalid credentials" do
    post customer_session_path, params: { email: @customer.email, password: "wrong" }

    assert_redirected_to new_customer_session_path
    assert_nil cookies[:customer_session_id]
  end

  test "logout terminates the customer session" do
    post customer_session_path, params: { email: @customer.email, password: "password123" }

    delete customer_session_path

    assert_redirected_to root_path
    assert_empty cookies[:customer_session_id]
  end

  test "does not grant admin access" do
    post customer_session_path, params: { email: @customer.email, password: "password123" }

    get admin_products_path
    assert_redirected_to new_session_path
  end
end
