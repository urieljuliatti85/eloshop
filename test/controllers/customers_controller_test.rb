require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "signing up creates a customer, starts a session, and associates the current cart" do
    get products_path # garante que um carrinho de sessão já exista via cookie

    assert_difference("Customer.count", 1) do
      post customers_path, params: {
        customer: {
          name: "Nova Cliente",
          email: "nova@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
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
end
