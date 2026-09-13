require "test_helper"

class HowItWorksControllerTest < ActionDispatch::IntegrationTest
  test "page is publicly accessible and shows both tabs" do
    get how_it_works_path

    assert_response :success
    assert_select "h1", "Como funciona"
    assert_select "[data-tab-name='compra']", 2
    assert_select "[data-tab-name='vende']", 2
  end
end
