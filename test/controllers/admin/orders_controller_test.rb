require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to admin login" do
    get admin_orders_path
    assert_redirected_to new_session_path
  end

  test "an authenticated admin can list orders" do
    sign_in_as(users(:one))

    get admin_orders_path

    assert_response :success
  end

  test "an authenticated admin can view any order" do
    sign_in_as(users(:one))

    get admin_order_path(orders(:one))

    assert_response :success
  end
end
