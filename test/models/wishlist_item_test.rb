require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  test "invalid when the same product is favorited twice by the same customer" do
    customer = customers(:one)
    customer.wishlist_items.create!(product: products(:one))

    duplicate = WishlistItem.new(customer: customer, product: products(:one))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end

  test "the same product can be favorited by different customers" do
    customers(:one).wishlist_items.create!(product: products(:one))

    item = WishlistItem.new(customer: customers(:two), product: products(:one))
    assert item.valid?
  end
end
