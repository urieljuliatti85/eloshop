require "test_helper"

class AddressesControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to customer login" do
    get new_address_path
    assert_redirected_to new_customer_session_path
  end

  test "an authenticated customer can register an address" do
    customer = customers(:one)
    post customer_session_path, params: { email: customer.email, password: "password123" }

    assert_difference("Address.count", 1) do
      post addresses_path, params: {
        address: {
          street: "Rua Nova",
          number: "10",
          neighborhood: "Bairro",
          city: "Cidade",
          state: "SP",
          zip_code: "00000-000"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal customer, Address.last.customer
  end

  test "does not admit an admin session as customer authentication" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    get new_address_path
    assert_redirected_to new_customer_session_path
  end
end
