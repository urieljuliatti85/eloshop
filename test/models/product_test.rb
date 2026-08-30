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

  test "to_param returns the slug" do
    assert_equal products(:one).slug, products(:one).to_param
  end

  test "has_variants? reflects whether the product has product_variants" do
    assert_not products(:one).has_variants?
    assert products(:with_variants).has_variants?
  end

  test "available_for_purchase? for a product with variants depends on the variants, not its own stock_quantity" do
    product = products(:with_variants)
    assert_equal 0, product.stock_quantity
    assert product.available_for_purchase?

    product.product_variants.update_all(active: false)
    assert_not product.reload.available_for_purchase?
  end

  test "available_for_purchase? is false for a product with variants that is not active" do
    product = products(:with_variants)
    product.update!(status: "draft")
    assert_not product.available_for_purchase?
  end

  test "cannot change availability_type away from standard once the product has variants" do
    product = products(:with_variants)
    product.availability_type = "made_to_order"
    assert_not product.valid?
    assert_includes product.errors[:availability_type], "não pode ser alterado enquanto o produto tiver variantes cadastradas"
  end

  test "one_of_a_kind rejects stock_quantity greater than 1" do
    product = Product.new(products(:one).attributes.except("id", "name", "slug", "sku").merge(
      "name" => "Peça única 1", "sku" => "UNICA-001", "availability_type" => "one_of_a_kind", "stock_quantity" => 2
    ))
    assert_not product.valid?
    assert_includes product.errors[:stock_quantity], "must be less than or equal to 1"
  end

  test "one_of_a_kind accepts stock_quantity of 1" do
    product = Product.new(products(:one).attributes.except("id", "name", "slug", "sku").merge(
      "name" => "Peça única 2", "sku" => "UNICA-002", "availability_type" => "one_of_a_kind", "stock_quantity" => 1
    ))
    assert product.valid?
  end

  test "one_of_a_kind cannot go back to active once sold out" do
    product = Product.new(products(:one).attributes.except("id", "name", "slug", "sku").merge(
      "name" => "Peça única 3", "sku" => "UNICA-003", "availability_type" => "one_of_a_kind", "stock_quantity" => 1
    )).tap(&:save!)

    product.update!(status: "sold_out")

    assert_raises(Product::InvalidStatusTransition) { product.publish! }
  end

  test "standard product can go back to active after sold out (restock)" do
    product = products(:one)
    product.update!(status: "sold_out")

    product.publish!

    assert product.active?
  end

  test "made_to_order requires a production time range" do
    product = Product.new(products(:one).attributes.except("id", "slug", "sku").merge(
      "sku" => "ENCOMENDA-001", "availability_type" => "made_to_order"
    ))
    assert_not product.valid?
    assert_includes product.errors[:production_time_min_days], "can't be blank"
    assert_includes product.errors[:production_time_max_days], "can't be blank"
  end

  test "made_to_order rejects a maximum lead time smaller than the minimum" do
    product = Product.new(products(:one).attributes.except("id", "slug", "sku").merge(
      "sku" => "ENCOMENDA-002", "availability_type" => "made_to_order",
      "production_time_min_days" => 10, "production_time_max_days" => 5
    ))
    assert_not product.valid?
    assert_includes product.errors[:production_time_max_days], "deve ser maior ou igual ao prazo mínimo"
  end

  test "made_to_order is available for purchase regardless of stock_quantity" do
    product = Product.new(products(:one).attributes.except("id", "slug", "sku").merge(
      "sku" => "ENCOMENDA-003", "availability_type" => "made_to_order",
      "production_time_min_days" => 7, "production_time_max_days" => 10, "stock_quantity" => 0
    ))

    assert product.available_for_purchase?
  end

  test "production_time_range formats the lead time for made_to_order products" do
    product = Product.new(availability_type: "made_to_order", production_time_min_days: 7, production_time_max_days: 10)
    assert_equal "7 a 10 dias úteis", product.production_time_range
  end

  test "production_time_range is nil for non made_to_order products" do
    assert_nil products(:one).production_time_range
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

  test "rejects a gallery image with disallowed content type" do
    product = products(:one)
    product.images.attach(io: StringIO.new("plain text"), filename: "doc.txt", content_type: "text/plain")

    assert_not product.valid?
    assert_includes product.errors[:images], "deve conter apenas arquivos PNG, JPEG ou WEBP"
  end

  test "rejects a gallery image larger than 5MB" do
    product = products(:one)
    large_content = "a" * (Product::MAIN_IMAGE_MAX_BYTES + 1)
    product.images.attach(io: StringIO.new(large_content), filename: "big.png", content_type: "image/png")

    assert_not product.valid?
    assert_includes product.errors[:images], "cada imagem deve ter no máximo 5MB"
  end

  test "rejects more than IMAGES_MAX_COUNT gallery images" do
    product = products(:one)
    (Product::IMAGES_MAX_COUNT + 1).times do |i|
      product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo#{i}.png", content_type: "image/png")
    end

    assert_not product.valid?
    assert_includes product.errors[:images], "não pode ter mais de #{Product::IMAGES_MAX_COUNT} imagens"
  end

  test "accepts valid gallery images" do
    product = products(:one)
    product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo.png", content_type: "image/png")

    assert product.valid?
  end

  test "gallery_images returns main_image first, then the rest of the gallery" do
    product = products(:one)
    product.main_image.attach(io: StringIO.new("cover"), filename: "cover.png", content_type: "image/png")
    product.images.attach(io: StringIO.new("extra"), filename: "extra.png", content_type: "image/png")

    photos = product.gallery_images
    assert_equal 2, photos.size
    assert_equal "cover.png", photos.first.filename.to_s
    assert_equal "extra.png", photos.second.filename.to_s
  end
end
