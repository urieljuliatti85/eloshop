require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to customer login" do
    get new_order_path
    assert_redirected_to new_customer_session_path
  end

  test "redirects to the cart when the cart is empty" do
    sign_in_customer(customers(:one))

    get new_order_path

    assert_redirected_to cart_path
  end

  test "an authenticated customer with items and an address can complete checkout" do
    customer = customers(:one)
    sign_in_customer(customer)
    add_item_to_current_cart(products(:one), quantity: 1)

    assert_difference("Order.count", 1) do
      post orders_path, params: { address_id: addresses(:one).id }
    end

    assert_redirected_to order_path(Order.last)
  end

  test "a customer can view their own order" do
    sign_in_customer(customers(:one))

    get order_path(orders(:one))

    assert_response :success
  end

  test "a customer cannot view another customer's order by guessing the URL" do
    sign_in_customer(customers(:one))

    get order_path(orders(:two))

    assert_response :not_found
  end

  private

  def sign_in_customer(customer)
    get new_customer_session_path
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  def add_item_to_current_cart(product, quantity:)
    post cart_items_path, params: { product_id: product.id, quantity: quantity }
  end
end
