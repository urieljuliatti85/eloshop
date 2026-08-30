require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @active_product = products(:one)
    @draft_product = products(:two)
  end

  test "lists active products without requiring authentication" do
    get products_path

    assert_response :success
    assert_select "a", text: /#{@active_product.name}/
  end

  test "does not list draft products" do
    get products_path

    assert_response :success
    assert_select "a", text: /#{@draft_product.name}/, count: 0
  end

  test "filters active products by category including descendants" do
    casa = Category.create!(name: "Casa")
    decoracao = casa.children.create!(name: "Decoração")
    @active_product.update!(category: decoracao)

    get products_path, params: { category: casa.slug }

    assert_response :success
    assert_select "a", text: /#{@active_product.name}/
  end

  test "returns not found for an unknown category filter" do
    get products_path, params: { category: "categoria-inexistente" }

    assert_response :not_found
  end

  test "searches by product name and filters by taxonomy" do
    tag = Tag.create!(name: "feito a mao")
    @active_product.tags << tag

    get products_path, params: { q: "Vaso", tag: tag.slug }

    assert_response :success
    assert_select "a", text: /#{@active_product.name}/
  end

  test "searches by category, material, and technique" do
    category = Category.create!(name: "Decoração")
    material = Material.create!(name: "Cerâmica")
    technique = Technique.create!(name: "Pintura")
    @active_product.update!(category: category)
    @active_product.materials << material
    @active_product.techniques << technique

    get products_path, params: { q: "Cerâmica" }
    assert_select "a", text: /#{@active_product.name}/

    get products_path, params: { q: "Pintura" }
    assert_select "a", text: /#{@active_product.name}/

    get products_path, params: { q: "Decoração" }
    assert_select "a", text: /#{@active_product.name}/
  end

  test "filters products by availability type" do
    made_to_order = Product.create!(
      name: "Encomenda especial", sku: "ENCOMENDA-001", price_cents: 1000,
      stock_quantity: 0, status: "active", availability_type: "made_to_order",
      production_time_min_days: 2, production_time_max_days: 4
    )

    get products_path, params: { availability: "made_to_order" }

    assert_select "a", text: /#{made_to_order.name}/
    assert_select "a", text: /#{@active_product.name}/, count: 0
  end

  test "shows an active product without requiring authentication" do
    get product_path(@active_product.slug)

    assert_response :success
    assert_select "h1", text: @active_product.name
  end

  test "returns 404 for a draft product accessed directly by slug" do
    get product_path(@draft_product.slug)

    assert_response :not_found
  end

  test "returns 404 for a discontinued product accessed directly by slug" do
    @active_product.discontinue!

    get product_path(@active_product.slug)

    assert_response :not_found
  end

  test "marks an out-of-stock active product as unavailable" do
    @active_product.update!(stock_quantity: 0)

    get product_path(@active_product.slug)

    assert_response :success
    assert_select "p", text: "Indisponível"
  end

  test "shows a product with variants including the variant selector" do
    product = products(:with_variants)

    get product_path(product.slug)

    assert_response :success
    assert_select "input[type='radio'][data-variant-selector-target='size']"
    assert_select "input[type='submit']"
  end

  test "shows a product with variants as unavailable when no active variant has stock" do
    product = products(:with_variants)
    product.product_variants.update_all(stock_quantity: 0)

    get product_path(product.slug)

    assert_response :success
    assert_select "p", text: "Indisponível"
  end

  test "shows a product with personalization fields, marking the required one" do
    product = products(:with_personalization)

    get product_path(product.slug)

    assert_response :success
    assert_select "input#personalization_#{personalization_options(:name_engraving).id}[required]"
    assert_select "input#personalization_#{personalization_options(:message).id}"
    assert_select "input#personalization_#{personalization_options(:message).id}[required]", count: 0
  end

  test "shows thumbnails when the product has more than one photo" do
    product = products(:one)
    product.main_image.attach(io: File.open(file_fixture("sample.png")), filename: "cover.png", content_type: "image/png")
    product.images.attach(io: File.open(file_fixture("sample.png")), filename: "extra.png", content_type: "image/png")

    get product_path(product.slug)

    assert_response :success
    assert_select "button[data-action='gallery#show']", count: 2
  end

  test "does not show thumbnails when the product has a single photo" do
    product = products(:one)
    product.main_image.attach(io: File.open(file_fixture("sample.png")), filename: "cover.png", content_type: "image/png")

    get product_path(product.slug)

    assert_response :success
    assert_select "button[data-action='gallery#show']", count: 0
  end

  test "shows related products excluding the current one" do
    get product_path(@active_product.slug)

    assert_response :success
    assert_select "h2", text: "Você também pode gostar"
    assert_select "a[href='#{product_path(@active_product.slug)}']", count: 0
  end
end
