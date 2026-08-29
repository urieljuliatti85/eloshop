require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "subtotal_cents sums each item's subtotal from the product's current price" do
    cart = carts(:one)
    # products(:one).price_cents == 8990, cart_items(:one).quantity == 1
    assert_equal 8990, cart.subtotal_cents
  end

  test "subtotal_cents reflects the product's current price, not a cached value" do
    cart = carts(:two)
    products(:one).update!(price_cents: 10_000)

    # cart_items(:two).quantity == 2
    assert_equal 20_000, cart.subtotal_cents
  end

  test "subtotal_cents is zero for an empty cart" do
    cart = Cart.create!(session_token: "empty-cart")
    assert_equal 0, cart.subtotal_cents
  end
end
