require "test_helper"

class SellerPortalHelperTest < ActionView::TestCase
  def build_product(**attrs)
    Product.new({ seller: sellers(:approved), name: "Peça", price_cents: 1_000, stock_quantity: 5 }.merge(attrs))
  end

  test "made-to-order products have no physical stock" do
    assert_equal "Sob encomenda", seller_stock_badge(build_product(availability_type: :made_to_order, stock_quantity: 0)).first
  end

  test "standard stock shows the count, warns when low and when empty" do
    assert_equal "5 em estoque", seller_stock_badge(build_product(stock_quantity: 5)).first
    assert_equal "Estoque baixo: #{Product::LOW_STOCK_THRESHOLD}", seller_stock_badge(build_product(stock_quantity: Product::LOW_STOCK_THRESHOLD)).first
    assert_equal "Sem estoque", seller_stock_badge(build_product(stock_quantity: 0)).first
  end

  test "a one-of-a-kind piece reads as unique or sold, never as low stock" do
    assert_equal "Peça única", seller_stock_badge(build_product(availability_type: :one_of_a_kind, stock_quantity: 1)).first
    assert_equal "Peça vendida", seller_stock_badge(build_product(availability_type: :one_of_a_kind, stock_quantity: 0)).first
  end
end
