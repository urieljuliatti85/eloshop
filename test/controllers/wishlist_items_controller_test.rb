require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = customers(:one)
  end

  def sign_in
    post customer_session_path, params: { email: @customer.email, password: "password123" }
  end

  test "redirects an unauthenticated visitor to customer login" do
    post wishlist_items_path, params: { product_id: products(:one).id }
    assert_redirected_to new_customer_session_path
  end

  test "favorites a product" do
    sign_in

    assert_difference("WishlistItem.count", 1) do
      post wishlist_items_path, params: { product_id: products(:one).id }
    end
  end

  test "favoriting the same product twice does not create a duplicate" do
    sign_in
    post wishlist_items_path, params: { product_id: products(:one).id }

    assert_no_difference("WishlistItem.count") do
      post wishlist_items_path, params: { product_id: products(:one).id }
    end
  end

  test "removes a favorited product" do
    sign_in
    item = @customer.wishlist_items.create!(product: products(:one))

    assert_difference("WishlistItem.count", -1) do
      delete wishlist_item_path(item)
    end
  end

  test "a customer cannot remove another customer's wishlist item" do
    sign_in
    other_item = customers(:two).wishlist_items.create!(product: products(:one))

    delete wishlist_item_path(other_item)

    assert_response :not_found
    assert WishlistItem.exists?(other_item.id)
  end

  test "moves a directly purchasable product to the cart and removes it from the wishlist" do
    sign_in
    item = @customer.wishlist_items.create!(product: products(:one))

    assert_difference("CartItem.count", 1) do
      post move_to_cart_wishlist_item_path(item)
    end

    assert_redirected_to cart_path
    assert_equal 0, @customer.wishlist_items.count
  end

  test "does not move a product that requires choosing a variant" do
    sign_in
    product_variants(:one) # garante que products(:with_variants) tem variante ativa
    item = @customer.wishlist_items.create!(product: products(:with_variants))

    assert_no_difference("CartItem.count") do
      post move_to_cart_wishlist_item_path(item)
    end

    assert_redirected_to product_path(products(:with_variants).seller, products(:with_variants).slug)
    assert_equal 1, @customer.wishlist_items.count
  end
end
