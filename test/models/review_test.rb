require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "invalid without a rating" do
    review = Review.new(customer: customers(:one), product: products(:one), comment: "Muito bom")
    assert_not review.valid?
    assert_includes review.errors[:rating], "can't be blank"
  end

  test "invalid with a rating outside 1..5" do
    review = Review.new(customer: customers(:one), product: products(:one), rating: 6, comment: "Muito bom")
    assert_not review.valid?
    assert_includes review.errors[:rating], "is not included in the list"
  end

  test "invalid without a comment" do
    review = Review.new(customer: customers(:one), product: products(:one), rating: 5)
    assert_not review.valid?
    assert_includes review.errors[:comment], "can't be blank"
  end

  test "invalid when the same customer reviews the same product twice" do
    customers(:one).reviews.create!(product: products(:one), rating: 5, comment: "Ótimo")

    duplicate = Review.new(customer: customers(:one), product: products(:one), rating: 4, comment: "De novo")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:customer_id], "já avaliou este produto"
  end

  test "defaults to pending status" do
    review = customers(:one).reviews.create!(product: products(:one), rating: 5, comment: "Ótimo")
    assert review.pending?
  end

  test "approve! and reject! transition status" do
    review = customers(:one).reviews.create!(product: products(:one), rating: 5, comment: "Ótimo")

    review.approve!
    assert review.approved?

    review.reject!
    assert review.rejected?
  end

  test "verified_purchase is true when the customer has a confirmed order with the product" do
    customer = customers(:one)
    product = products(:one)
    address = addresses(:one)
    order = customer.orders.create!(
      status: "confirmed", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
      shipping_address_snapshot: address.attributes.slice("street", "number", "city", "state", "zip_code"),
      idempotency_key: SecureRandom.hex(10)
    )
    seller_order = order.seller_orders.create!(seller: product.seller, status: :confirmed, subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000, platform_fee_cents: 150, seller_amount_cents: 850)
    order.order_items.create!(seller_order: seller_order, product: product, product_name: product.name, sku: product.sku, unit_price_cents: 1000, quantity: 1)

    review = customer.reviews.create!(product: product, rating: 5, comment: "Chegou rápido")

    assert review.verified_purchase?
  end

  test "verified_purchase is false without a confirmed order for the product" do
    review = customers(:one).reviews.create!(product: products(:one), rating: 5, comment: "Ótimo")
    assert_not review.verified_purchase?
  end

  test "verified_purchase is false when the order with the product is still pending" do
    customer = customers(:two)
    product = products(:one)
    order = orders(:two)
    assert order.pending?
    assert_equal product, order_items(:two).product

    review = customer.reviews.create!(product: product, rating: 5, comment: "Ótimo")

    assert_not review.verified_purchase?
  end
end
