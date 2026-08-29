require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  test "subtotal_cents is quantity times the product's current price" do
    item = cart_items(:one)
    assert_equal item.product.price_cents * item.quantity, item.subtotal_cents
  end

  test "invalid with quantity zero or negative" do
    item = CartItem.new(cart: carts(:one), product: products(:one), quantity: 0)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "invalid when the product is not active" do
    item = CartItem.new(cart: carts(:one), product: products(:two), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product], "não está disponível para compra"
  end

  test "invalid when the product is active but out of stock" do
    item = CartItem.new(cart: carts(:one), product: products(:three), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product], "não está disponível para compra"
  end

  test "invalid when quantity exceeds available stock" do
    item = CartItem.new(cart: carts(:one), product: products(:one), quantity: products(:one).stock_quantity + 1)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "não pode ser maior que o estoque disponível"
  end

  test "invalid when the same product is added twice to the same cart" do
    duplicate = CartItem.new(cart: cart_items(:one).cart, product: cart_items(:one).product, quantity: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end
end
