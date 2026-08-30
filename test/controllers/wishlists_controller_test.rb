require "test_helper"

class WishlistsControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to customer login" do
    get wishlist_path
    assert_redirected_to new_customer_session_path
  end

  test "lists the customer's favorited products" do
    customer = customers(:one)
    post customer_session_path, params: { email: customer.email, password: "password123" }
    customer.wishlist_items.create!(product: products(:one))

    get wishlist_path

    assert_response :success
    assert_match products(:one).name, response.body
  end
end
