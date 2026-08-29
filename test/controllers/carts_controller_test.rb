require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "shows the current cart without requiring authentication" do
    get cart_path
    assert_response :success
  end

  test "cart persists across requests in the same session via cookie" do
    post cart_items_path, params: { product_id: products(:one).id, quantity: 1 }

    get cart_path
    assert_response :success
    assert_select "td", text: products(:one).name
  end
end
