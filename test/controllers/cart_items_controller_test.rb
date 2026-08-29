require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  test "adding a product creates a cart item" do
    assert_difference("CartItem.count", 1) do
      post cart_items_path, params: { product_id: products(:one).id, quantity: 2 }
    end

    assert_redirected_to cart_path
  end

  test "adding the same product twice sums the quantity instead of erroring" do
    post cart_items_path, params: { product_id: products(:one).id, quantity: 1 }

    assert_no_difference("CartItem.count") do
      post cart_items_path, params: { product_id: products(:one).id, quantity: 2 }
    end

    item = CartItem.order(created_at: :desc).first
    assert_equal 3, item.quantity
  end

  test "does not add an unavailable product" do
    assert_no_difference("CartItem.count") do
      post cart_items_path, params: { product_id: products(:two).id, quantity: 1 }
    end

    assert_redirected_to product_path(products(:two))
  end

  test "does not add a quantity greater than available stock" do
    assert_no_difference("CartItem.count") do
      post cart_items_path, params: { product_id: products(:one).id, quantity: products(:one).stock_quantity + 1 }
    end
  end

  test "updating quantity changes the item and the total" do
    post cart_items_path, params: { product_id: products(:one).id, quantity: 1 }
    item = CartItem.order(created_at: :desc).first

    patch cart_item_path(item), params: { quantity: 3 }

    assert_redirected_to cart_path
    assert_equal 3, item.reload.quantity
  end

  test "removing an item deletes it from the cart" do
    post cart_items_path, params: { product_id: products(:one).id, quantity: 1 }
    item = CartItem.order(created_at: :desc).first

    assert_difference("CartItem.count", -1) do
      delete cart_item_path(item)
    end

    assert_redirected_to cart_path
  end

  test "works without requiring authentication" do
    post cart_items_path, params: { product_id: products(:one).id, quantity: 1 }
    assert_redirected_to cart_path
  end

  test "adding a product with a variant creates a cart item tied to that variant" do
    assert_difference("CartItem.count", 1) do
      post cart_items_path, params: {
        product_id: products(:with_variants).id, product_variant_id: product_variants(:one).id, quantity: 1
      }
    end

    assert_redirected_to cart_path
    assert_equal product_variants(:one), CartItem.order(created_at: :desc).first.product_variant
  end

  test "does not add a product with variants without choosing one" do
    assert_no_difference("CartItem.count") do
      post cart_items_path, params: { product_id: products(:with_variants).id, quantity: 1 }
    end

    assert_redirected_to product_path(products(:with_variants))
  end

  test "adding two different variants of the same product creates two cart items" do
    product_variants(:two).update!(stock_quantity: 3)

    post cart_items_path, params: {
      product_id: products(:with_variants).id, product_variant_id: product_variants(:one).id, quantity: 1
    }

    assert_difference("CartItem.count", 1) do
      post cart_items_path, params: {
        product_id: products(:with_variants).id, product_variant_id: product_variants(:two).id, quantity: 1
      }
    end
  end
end
