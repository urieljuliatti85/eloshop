require "test_helper"
require "stringio"

class ProductTest < ActiveSupport::TestCase
  test "requires a seller" do
    product = Product.new(name: "Peça", sku: "PECA-SEM-VENDEDOR", price_cents: 1000, stock_quantity: 1)

    assert_not product.valid?
    assert_includes product.errors[:seller], "must exist"
  end

  test "slug and SKU are unique per seller" do
    original = products(:one)
    duplicate = original.dup
    duplicate.seller = sellers(:other)

    assert duplicate.valid?
    assert duplicate.save
  end

  test "seller must be approved before publishing" do
    product = products(:two)
    product.update!(seller: sellers(:pending))

    error = assert_raises(Product::InvalidStatusTransition) { product.publish! }
    assert_equal "o vendedor precisa estar aprovado antes da publicação", error.message
  end

  test "seller cannot change after the product participates in an order" do
    product = products(:one)

    assert_not product.update(seller: sellers(:other))
    assert_includes product.errors[:seller], "não pode ser alterado depois que o produto participa de um pedido"
  end
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

  test "to_param uses the stable id outside the seller-scoped storefront route" do
    assert_equal products(:one).id.to_s, products(:one).to_param
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

  test "related_products excludes itself and non-active products" do
    related = products(:one).related_products

    assert_not_includes related, products(:one)
    assert_not_includes related, products(:two)
  end

  test "related_products only returns active products" do
    assert products(:one).related_products.all?(&:active?)
  end

  test "related_products respects the limit" do
    assert products(:one).related_products(limit: 1).size <= 1
  end

  test "average_rating and reviews_count only consider approved reviews" do
    product = products(:one)
    product.reviews.create!(customer: customers(:one), rating: 5, comment: "Ótimo", status: "approved")
    product.reviews.create!(customer: customers(:two), rating: 3, comment: "Pendente")

    assert_equal 5.0, product.average_rating
    assert_equal 1, product.reviews_count
  end

  test "average_rating is nil without approved reviews" do
    assert_nil products(:one).average_rating
    assert_equal 0, products(:one).reviews_count
  end

  test "low_stock includes active standard products at or below the threshold" do
    product = Product.create!(seller: sellers(:approved), name: "Baixo estoque", sku: "LOW-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: Product::LOW_STOCK_THRESHOLD, currency: "BRL", status: "active", availability_type: "standard")

    assert_includes Product.low_stock, product
  end

  test "low_stock excludes products above the threshold" do
    product = Product.create!(seller: sellers(:approved), name: "Estoque normal", sku: "LOW-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: Product::LOW_STOCK_THRESHOLD + 1, currency: "BRL", status: "active", availability_type: "standard")

    assert_not_includes Product.low_stock, product
  end

  test "low_stock excludes sold out products" do
    product = Product.create!(seller: sellers(:approved), name: "Esgotado", sku: "LOW-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 0, currency: "BRL", status: "sold_out", availability_type: "standard")

    assert_not_includes Product.low_stock, product
  end

  test "low_stock excludes made_to_order products" do
    product = Product.create!(seller: sellers(:approved), name: "Sob encomenda", sku: "LOW-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 0, currency: "BRL", status: "active", availability_type: "made_to_order", production_time_min_days: 1, production_time_max_days: 2)

    assert_not_includes Product.low_stock, product
  end

  test "low_stock excludes a product whose variants own the stock" do
    product = Product.create!(seller: sellers(:approved), name: "Produto com variantes", sku: "LOW-VAR-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 0, currency: "BRL", status: "active")
    product.product_variants.create!(sku: "LOW-VAR-P-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 2, size: "P")

    assert_not_includes Product.low_stock, product
  end
end
