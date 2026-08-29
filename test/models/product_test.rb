require "test_helper"
require "stringio"

class ProductTest < ActiveSupport::TestCase
  test "invalid without name" do
    product = Product.new(products(:one).attributes.except("id", "name"))
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "invalid without sku" do
    product = Product.new(products(:one).attributes.except("id", "sku"))
    assert_not product.valid?
    assert_includes product.errors[:sku], "can't be blank"
  end

  test "invalid with duplicate slug" do
    duplicate = Product.new(products(:two).attributes.except("id").merge("slug" => products(:one).slug, "sku" => "OUTRO-SKU"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "invalid with duplicate sku" do
    duplicate = Product.new(products(:two).attributes.except("id").merge("sku" => products(:one).sku, "slug" => "outro-slug"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sku], "has already been taken"
  end

  test "invalid with negative price_cents" do
    product = Product.new(products(:one).attributes.except("id").merge("price_cents" => -1, "slug" => nil, "sku" => "NEG-PRICE"))
    assert_not product.valid?
    assert_includes product.errors[:price_cents], "must be greater than or equal to 0"
  end

  test "invalid with negative stock_quantity" do
    product = Product.new(products(:one).attributes.except("id").merge("stock_quantity" => -1, "slug" => nil, "sku" => "NEG-STOCK"))
    assert_not product.valid?
    assert_includes product.errors[:stock_quantity], "must be greater than or equal to 0"
  end

  test "assigns slug from name when slug is blank" do
    product = Product.new(name: "Tapete de Fibra Natural", sku: "TAPETE-001", price_cents: 1000, stock_quantity: 1, currency: "BRL")
    product.valid?
    assert_equal "tapete-de-fibra-natural", product.slug
  end

  test "does not overwrite an explicitly assigned slug" do
    product = Product.new(name: "Tapete de Fibra Natural", slug: "meu-slug-personalizado", sku: "TAPETE-002", price_cents: 1000, stock_quantity: 1, currency: "BRL")
    product.valid?
    assert_equal "meu-slug-personalizado", product.slug
  end

  test "publish! transitions draft to active" do
    product = products(:two)
    product.publish!
    assert product.active?
  end

  test "publish! raises for a discontinued product" do
    product = products(:one)
    product.discontinue!
    assert_raises(Product::InvalidStatusTransition) { product.publish! }
  end

  test "unpublish! transitions active to draft" do
    product = products(:one)
    product.unpublish!
    assert product.draft?
  end

  test "discontinue! raises for a draft product" do
    product = products(:two)
    assert_raises(Product::InvalidStatusTransition) { product.discontinue! }
  end

  test "discontinued is a terminal state" do
    product = products(:one)
    product.discontinue!
    assert_raises(Product::InvalidStatusTransition) { product.publish! }
    assert_raises(Product::InvalidStatusTransition) { product.unpublish! }
  end

  test "available_for_purchase? is true only when active with stock" do
    assert products(:one).available_for_purchase?
    assert_not products(:two).available_for_purchase?

    out_of_stock = products(:one)
    out_of_stock.update!(stock_quantity: 0)
    assert_not out_of_stock.available_for_purchase?
  end

  test "rejects main_image with disallowed content type" do
    product = products(:one)
    product.main_image.attach(io: StringIO.new("plain text"), filename: "doc.txt", content_type: "text/plain")

    assert_not product.valid?
    assert_includes product.errors[:main_image], "deve ser um arquivo PNG, JPEG ou WEBP"
  end

  test "rejects main_image larger than 5MB" do
    product = products(:one)
    large_content = "a" * (Product::MAIN_IMAGE_MAX_BYTES + 1)
    product.main_image.attach(io: StringIO.new(large_content), filename: "big.png", content_type: "image/png")

    assert_not product.valid?
    assert_includes product.errors[:main_image], "deve ter no máximo 5MB"
  end

  test "accepts a valid main_image" do
    product = products(:one)
    product.main_image.attach(io: StringIO.new("fake image bytes"), filename: "photo.png", content_type: "image/png")

    assert product.valid?
  end
end
