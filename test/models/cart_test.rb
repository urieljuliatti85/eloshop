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

  test "production_time_max_days is nil when nothing in the cart is made to order" do
    assert_nil carts(:one).production_time_max_days
  end

  # O envio só sai quando a peça mais demorada fica pronta.
  test "production_time_max_days is the longest lead time among made-to-order pieces" do
    products(:one).update!(availability_type: :made_to_order, stock_quantity: 0, production_time_min_days: 7, production_time_max_days: 12)

    assert_equal 12, carts(:one).production_time_max_days
  end
end
