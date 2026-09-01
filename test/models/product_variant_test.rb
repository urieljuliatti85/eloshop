require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  test "invalid without sku" do
    variant = ProductVariant.new(product_variants(:one).attributes.except("id", "sku"))
    assert_not variant.valid?
    assert_includes variant.errors[:sku], "can't be blank"
  end

  test "invalid with duplicate sku" do
    duplicate = ProductVariant.new(product_variants(:two).attributes.except("id").merge("sku" => product_variants(:one).sku))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sku], "has already been taken"
  end

  test "invalid with negative price_cents" do
    variant = ProductVariant.new(product_variants(:one).attributes.except("id", "sku").merge("sku" => "NEW-SKU", "price_cents" => -1))
    assert_not variant.valid?
    assert_includes variant.errors[:price_cents], "must be greater than or equal to 0"
  end

  test "invalid with negative stock_quantity" do
    variant = ProductVariant.new(product_variants(:one).attributes.except("id", "sku").merge("sku" => "NEW-SKU", "stock_quantity" => -1))
    assert_not variant.valid?
    assert_includes variant.errors[:stock_quantity], "must be greater than or equal to 0"
  end

  test "invalid without at least one axis (size, color or material)" do
    variant = ProductVariant.new(product_variants(:one).attributes.except("id", "sku").merge("sku" => "NEW-SKU", "size" => nil))
    assert_not variant.valid?
    assert_includes variant.errors[:base], "deve informar ao menos um entre tamanho, cor ou material"
  end

  test "invalid when the same combination already exists for the product" do
    duplicate = ProductVariant.new(
      product: product_variants(:one).product, sku: "NEW-SKU", price_cents: 1000, stock_quantity: 1,
      size: product_variants(:one).size, color: product_variants(:one).color, material: product_variants(:one).material
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end

  test "invalid when the product does not support variants" do
    made_to_order_product = Product.new(
      products(:one).attributes.except("id", "slug", "sku").merge(
        "sku" => "MADE-001", "availability_type" => "made_to_order",
        "production_time_min_days" => 7, "production_time_max_days" => 10
      )
    )

    variant = ProductVariant.new(product: made_to_order_product, sku: "NEW-SKU", price_cents: 1000, stock_quantity: 1, size: "P")
    assert_not variant.valid?
    assert_includes variant.errors[:product], "só pode ter variantes quando o tipo de disponibilidade é padrão (estoque)"
  end

  test "available_for_purchase? is true only when active with stock" do
    assert product_variants(:one).available_for_purchase?
    assert_not product_variants(:two).available_for_purchase?

    inactive = product_variants(:one)
    inactive.active = false
    assert_not inactive.available_for_purchase?
  end

  test "to_label joins the present axes" do
    variant = ProductVariant.new(size: "P", color: "Azul", material: nil)
    assert_equal "P / Azul", variant.to_label
  end

  test "inventory scopes use active variant stock, not the parent product stock" do
    low_stock_variant = product_variants(:one)
    sold_out_variant = product_variants(:two)
    low_stock_variant.product.update!(status: :active, stock_quantity: 0)

    assert_includes ProductVariant.low_stock, low_stock_variant
    assert_includes ProductVariant.out_of_stock, sold_out_variant
  end
end
