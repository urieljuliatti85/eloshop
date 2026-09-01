require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
  end

  test "redirects unauthenticated access to login" do
    get admin_products_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can list products" do
    sign_in_as(@user)

    get admin_products_path
    assert_response :success
  end

  test "authenticated user can view a product" do
    sign_in_as(@user)

    get admin_product_path(@product)
    assert_response :success
  end

  test "creates a product with valid params" do
    sign_in_as(@user)

    assert_difference("Product.count", 1) do
      post admin_products_path, params: {
        product: {
          seller_id: sellers(:approved).id,
          name: "Cesto de vime",
          description: "Cesto trançado à mão",
          price_cents: 5990,
          currency: "BRL",
          sku: "CESTO-001",
          stock_quantity: 2
        }
      }
    end

    assert_redirected_to admin_product_path(Product.last)
  end

  test "creates a product with discovery taxonomies" do
    sign_in_as(@user)

    post admin_products_path, params: {
      product: {
        seller_id: sellers(:approved).id,
        name: "Cesto catalogado", description: "Cesto", price_cents: 5990,
        currency: "BRL", sku: "CESTO-CATALOGADO-001", stock_quantity: 2,
        tag_names: "feito a mao, presente", material_names: "Vime",
        technique_names: "Trançado"
      }
    }

    product = Product.find_by!(sku: "CESTO-CATALOGADO-001")
    assert_equal %w[feito-a-mao presente], product.tags.order(:slug).pluck(:slug)
    assert_equal [ "vime" ], product.materials.pluck(:slug)
    assert_equal [ "trancado" ], product.techniques.pluck(:slug)
  end

  test "does not create a product with invalid params" do
    sign_in_as(@user)

    assert_no_difference("Product.count") do
      post admin_products_path, params: { product: { name: "", sku: "", price_cents: 0, stock_quantity: 0 } }
    end

    assert_response :unprocessable_entity
  end

  test "updates a product with valid params" do
    sign_in_as(@user)

    patch admin_product_path(@product), params: { product: { name: "Vaso artesanal azul (edição limitada)" } }

    assert_redirected_to admin_product_path(@product)
    assert_equal "Vaso artesanal azul (edição limitada)", @product.reload.name
  end

  test "publishes a draft product" do
    sign_in_as(@user)
    draft_product = products(:two)

    patch publish_admin_product_path(draft_product)

    assert_redirected_to admin_product_path(draft_product)
    assert draft_product.reload.active?
  end

  test "rejects an invalid status transition" do
    sign_in_as(@user)
    @product.discontinue!

    patch publish_admin_product_path(@product)

    assert_redirected_to admin_product_path(@product)
    assert_equal "discontinued", @product.reload.status
  end

  test "creates a one_of_a_kind product" do
    sign_in_as(@user)

    post admin_products_path, params: {
      product: {
        seller_id: sellers(:approved).id,
        name: "Escultura única", description: "Peça única", price_cents: 15_000,
        currency: "BRL", sku: "UNICA-ADMIN-001", stock_quantity: 1, availability_type: "one_of_a_kind"
      }
    }

    assert Product.last.availability_type_one_of_a_kind?
  end

  test "creates a made_to_order product with a production time range" do
    sign_in_as(@user)

    post admin_products_path, params: {
      product: {
        seller_id: sellers(:approved).id,
        name: "Cadeira sob encomenda", description: "Feita sob encomenda", price_cents: 30_000,
        currency: "BRL", sku: "ENCOMENDA-ADMIN-001", stock_quantity: 0,
        availability_type: "made_to_order", production_time_min_days: 15, production_time_max_days: 20
      }
    }

    product = Product.last
    assert product.availability_type_made_to_order?
    assert_equal "15 a 20 dias úteis", product.production_time_range
  end

  test "attaches gallery images on update" do
    sign_in_as(@user)

    patch admin_product_path(@product), params: {
      product: { name: @product.name, images: [ fixture_file_upload("sample.png", "image/png") ] }
    }

    assert_redirected_to admin_product_path(@product)
    assert_equal 1, @product.reload.images.count
  end

  test "attaching gallery images does not remove previously attached ones" do
    sign_in_as(@user)
    @product.images.attach(io: File.open(file_fixture("sample.png")), filename: "first.png", content_type: "image/png")

    patch admin_product_path(@product), params: {
      product: { name: @product.name, images: [ fixture_file_upload("sample.png", "image/png") ] }
    }

    assert_equal 2, @product.reload.images.count
  end

  test "rejects a gallery image with a disallowed content type without discarding the rest of the update" do
    sign_in_as(@user)

    patch admin_product_path(@product), params: {
      product: { name: "Nome novo", images: [ fixture_file_upload("sample.png", "text/plain") ] }
    }

    assert_redirected_to admin_product_path(@product)
    assert_equal "Nome novo", @product.reload.name
    assert_equal 0, @product.images.count
  end

  test "removes a gallery image" do
    sign_in_as(@user)
    @product.images.attach(io: File.open(file_fixture("sample.png")), filename: "first.png", content_type: "image/png")
    attachment = @product.images.attachments.first

    delete admin_product_product_image_path(@product, attachment)

    assert_redirected_to admin_product_path(@product)
    assert_equal 0, @product.reload.images.count
  end
end
