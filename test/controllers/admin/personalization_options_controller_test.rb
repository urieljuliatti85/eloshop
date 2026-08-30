require "test_helper"

class Admin::PersonalizationOptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:with_personalization)
    @option = personalization_options(:name_engraving)
  end

  test "redirects unauthenticated access to login" do
    get new_admin_product_personalization_option_path(@product)
    assert_redirected_to new_session_path
  end

  test "authenticated user can view the new personalization option form" do
    sign_in_as(@user)

    get new_admin_product_personalization_option_path(@product)
    assert_response :success
  end

  test "creates a personalization option with valid params" do
    sign_in_as(@user)

    assert_difference("PersonalizationOption.count", 1) do
      post admin_product_personalization_options_path(@product), params: {
        personalization_option: { label: "Cor da linha", required: false, max_length: 20 }
      }
    end

    assert_redirected_to admin_product_path(@product)
  end

  test "does not create a personalization option with invalid params" do
    sign_in_as(@user)

    assert_no_difference("PersonalizationOption.count") do
      post admin_product_personalization_options_path(@product), params: {
        personalization_option: { label: "", required: false, max_length: 20 }
      }
    end

    assert_response :unprocessable_entity
  end

  test "updates a personalization option with valid params" do
    sign_in_as(@user)

    patch admin_product_personalization_option_path(@product, @option), params: { personalization_option: { max_length: 50 } }

    assert_redirected_to admin_product_path(@product)
    assert_equal 50, @option.reload.max_length
  end

  test "destroys a personalization option even when already used in past orders" do
    sign_in_as(@user)
    order_items(:one).update!(personalizations: [ { "label" => @option.label, "value" => "Maria" } ])

    assert_difference("PersonalizationOption.count", -1) do
      delete admin_product_personalization_option_path(@product, @option)
    end

    assert_redirected_to admin_product_path(@product)
    # O pedido preserva o snapshot mesmo com a opção excluída (sem FK).
    assert_equal "Maria", order_items(:one).reload.personalization_entries.first[:value]
  end
end
