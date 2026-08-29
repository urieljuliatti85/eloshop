require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
  end

  test "redirects unauthenticated access to login" do
    get admin_products_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can list products" do
    sign_in_as(@user)

    get admin_products_path
    assert_response :success
  end

  test "authenticated user can view a product" do
    sign_in_as(@user)

    get admin_product_path(@product)
    assert_response :success
  end

  test "creates a product with valid params" do
    sign_in_as(@user)

    assert_difference("Product.count", 1) do
      post admin_products_path, params: {
        product: {
          name: "Cesto de vime",
          description: "Cesto trançado à mão",
          price_cents: 5990,
          currency: "BRL",
          sku: "CESTO-001",
          stock_quantity: 2
        }
      }
    end

    assert_redirected_to admin_product_path(Product.last)
  end

  test "does not create a product with invalid params" do
    sign_in_as(@user)

    assert_no_difference("Product.count") do
      post admin_products_path, params: { product: { name: "", sku: "", price_cents: 0, stock_quantity: 0 } }
    end

    assert_response :unprocessable_entity
  end

  test "updates a product with valid params" do
    sign_in_as(@user)

    patch admin_product_path(@product), params: { product: { name: "Vaso artesanal azul (edição limitada)" } }

    assert_redirected_to admin_product_path(@product)
    assert_equal "Vaso artesanal azul (edição limitada)", @product.reload.name
  end

  test "publishes a draft product" do
    sign_in_as(@user)
    draft_product = products(:two)

    patch publish_admin_product_path(draft_product)

    assert_redirected_to admin_product_path(draft_product)
    assert draft_product.reload.active?
  end

  test "rejects an invalid status transition" do
    sign_in_as(@user)
    @product.discontinue!

    patch publish_admin_product_path(@product)

    assert_redirected_to admin_product_path(@product)
    assert_equal "discontinued", @product.reload.status
  end
end
