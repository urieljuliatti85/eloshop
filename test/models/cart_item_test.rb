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

  test "invalid without a variant when the product has variants" do
    item = CartItem.new(cart: carts(:one), product: products(:with_variants), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product_variant], "deve ser escolhida para este produto"
  end

  test "invalid with a variant when the product has no variants" do
    item = CartItem.new(cart: carts(:one), product: products(:one), product_variant: product_variants(:one), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product_variant], "não pertence a este produto"
  end

  test "invalid with a variant that belongs to a different product" do
    other_product = Product.create!(name: "Outro produto", sku: "OUTRO-VAR-001", price_cents: 1000, stock_quantity: 1, currency: "BRL", status: "active")
    item = CartItem.new(cart: carts(:one), product: other_product, product_variant: product_variants(:one), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product_variant], "não pertence a este produto"
  end

  test "valid with an available variant and unit_price_cents/subtotal_cents use the variant's price" do
    item = CartItem.new(cart: carts(:one), product: products(:with_variants), product_variant: product_variants(:one), quantity: 2)
    assert item.valid?
    assert_equal product_variants(:one).price_cents, item.unit_price_cents
    assert_equal product_variants(:one).price_cents * 2, item.subtotal_cents
  end

  test "invalid when the chosen variant is out of stock" do
    item = CartItem.new(cart: carts(:one), product: products(:with_variants), product_variant: product_variants(:two), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:product_variant], "não está disponível para compra"
  end

  test "invalid when quantity exceeds the variant's stock" do
    item = CartItem.new(
      cart: carts(:one), product: products(:with_variants), product_variant: product_variants(:one),
      quantity: product_variants(:one).stock_quantity + 1
    )
    assert_not item.valid?
    assert_includes item.errors[:quantity], "não pode ser maior que o estoque disponível"
  end

  test "two different variants of the same product can coexist in the same cart" do
    cart = carts(:one)
    cart.cart_items.create!(product: products(:with_variants), product_variant: product_variants(:one), quantity: 1)
    second = CartItem.new(cart: cart, product: products(:with_variants), product_variant: product_variants(:two), quantity: 1)

    # product_variants(:two) está sem estoque no fixture — troca só para
    # validar a regra de unicidade por variante, não a de estoque.
    second.product_variant.stock_quantity = 1
    assert second.valid?
  end
end
