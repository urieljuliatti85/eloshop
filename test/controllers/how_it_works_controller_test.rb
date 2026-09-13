require "test_helper"

class HowItWorksControllerTest < ActionDispatch::IntegrationTest
  test "customer page is publicly accessible" do
    get how_it_works_path

    assert_response :success
    assert_select "h1", "Como funciona para quem compra"
  end

  test "seller page is publicly accessible" do
    get how_to_sell_path

    assert_response :success
    assert_select "h1", "Como funciona para quem vende"
  end
end
