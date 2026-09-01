require "test_helper"

class SellerTest < ActiveSupport::TestCase
  test "assigns a slug and starts pending" do
    seller = Seller.create!(name: "Ateliê da Lua")

    assert_equal "atelie-da-lua", seller.slug
    assert_predicate seller, :pending?
    assert_nil seller.approved_at
  end

  test "approval and suspension preserve explicit status" do
    seller = sellers(:pending)

    seller.approve!
    assert_predicate seller, :approved?
    assert_not_nil seller.approved_at

    seller.suspend!
    assert_predicate seller, :suspended?
    assert_nil seller.approved_at
  end
end
