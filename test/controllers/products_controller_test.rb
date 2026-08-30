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
end
