require "test_helper"

class Admin::ProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:with_variants)
    @variant = product_variants(:one)
  end

  test "redirects unauthenticated access to login" do
    get new_admin_product_product_variant_path(@product)
    assert_redirected_to new_session_path
  end

  test "authenticated user can view the new variant form" do
    sign_in_as(@user)

    get new_admin_product_product_variant_path(@product)
    assert_response :success
  end

  test "creates a variant with valid params" do
    sign_in_as(@user)

    assert_difference("ProductVariant.count", 1) do
      post admin_product_product_variants_path(@product), params: {
        product_variant: { sku: "CAMISETA-001-M", price_cents: 7500, stock_quantity: 4, size: "M" }
      }
    end

    assert_redirected_to admin_product_path(@product)
  end

  test "does not create a variant with invalid params" do
    sign_in_as(@user)

    assert_no_difference("ProductVariant.count") do
      post admin_product_product_variants_path(@product), params: {
        product_variant: { sku: "", price_cents: 7500, stock_quantity: 4, size: "M" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "updates a variant with valid params" do
    sign_in_as(@user)

    patch admin_product_product_variant_path(@product, @variant), params: { product_variant: { stock_quantity: 9 } }

    assert_redirected_to admin_product_path(@product)
    assert_equal 9, @variant.reload.stock_quantity
  end

  test "destroys a variant that was never ordered" do
    sign_in_as(@user)

    assert_difference("ProductVariant.count", -1) do
      delete admin_product_product_variant_path(@product, @variant)
    end

    assert_redirected_to admin_product_path(@product)
  end

  test "does not destroy a variant already referenced by an order item" do
    sign_in_as(@user)
    order_items(:one).update!(product_variant: @variant)

    assert_no_difference("ProductVariant.count") do
      delete admin_product_product_variant_path(@product, @variant)
    end

    assert_redirected_to admin_product_path(@product)
    follow_redirect!
    assert_match "não pode ser excluída", response.body
  end
end
