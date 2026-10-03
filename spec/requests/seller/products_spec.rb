require "rails_helper"

RSpec.describe "Seller products", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Um", owner_full_name: "Proprietário Teste", cpf: "13444462727", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Ateliê Dois", owner_full_name: "Proprietário Teste", cpf: "13555574450", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:own_product) { Product.create!(seller: seller, name: "Vaso próprio", sku: "OWN-001", price_cents: 5_000, stock_quantity: 2) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Vaso alheio", sku: "OTHER-001", price_cents: 5_000, stock_quantity: 2) }

  before { sign_in_as(user) }

  it "lists only the authenticated seller products" do
    own_product
    other_product

    get seller_products_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vaso próprio")
    expect(response.body).not_to include("Vaso alheio")
  end

  it "renders the edit form with the category breadcrumb" do
    top = Category.create!(name: "Casa")
    child = Category.create!(name: "Decoração", parent: top)
    own_product.update!(category: child)

    get edit_seller_product_path(own_product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Casa &gt; Decoração")
  end

  # O seletor de categoria do formulário renderiza o breadcrumb de cada opção,
  # e `Category#breadcrumb_name` sobe a árvore uma query por nível. A asserção é
  # sobre o crescimento: o total muda quando a página muda, a inclinação não
  # pode voltar. Diferente do admin, este painel tem tráfego proporcional ao
  # número de artesãos.
  it "does not issue more queries on the product form when categories are added" do
    top = Category.create!(name: "Casa")
    child = Category.create!(name: "Decoração", parent: top)
    Category.create!(name: "Vasos", parent: child)

    get new_seller_product_path
    before = count_queries { get new_seller_product_path }

    other = Category.create!(name: "Moda")
    sub = Category.create!(name: "Acessórios", parent: other)
    Category.create!(name: "Colares", parent: sub)

    get new_seller_product_path
    after = count_queries { get new_seller_product_path }

    expect(after).to eq(before)
  end

  it "searches only within the authenticated seller catalog" do
    own_product
    Product.create!(seller: seller, name: "Caneca própria", sku: "OWN-002", price_cents: 3_000, stock_quantity: 2)
    other_product

    get seller_products_path, params: { q: "Caneca" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Caneca própria")
    expect(response.body).not_to include("Vaso próprio", "Vaso alheio")
  end

  it "does not expose another seller product by changing the id" do
    get seller_product_path(other_product)

    expect(response).to have_http_status(:not_found)
  end

  it "shows the owned product management sections" do
    own_product.product_variants.create!(sku: "OWN-001-AZUL", price_cents: 5_000, stock_quantity: 1, color: "Azul")
    own_product.personalization_options.create!(label: "Nome", required: false, max_length: 20)

    get seller_product_path(own_product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Variantes", "OWN-001-AZUL", "Personalizações", "Galeria")
  end

  it "assigns newly created products to the authenticated seller" do
    expect do
      post seller_products_path, params: { product: { name: "Nova peça", sku: "NEW-001", price: "40,00", currency: "BRL", stock_quantity: 1 } }
    end.to change(seller.products, :count).by(1)

    expect(Product.last.seller).to eq(seller)
  end

  it "appends valid gallery images when updating an owned product" do
    image = fixture_file_upload("sample.png", "image/png")

    expect do
      patch seller_product_path(own_product), params: { product: { images: [ image ] } }
    end.to change { own_product.images.reload.count }.by(1)

    expect(response).to redirect_to(seller_product_path(own_product))
  end

  describe "photo optimization on upload" do
    # Ruído puro não comprime: um JPEG de ~9 MB, como uma foto grande de celular.
    def big_phone_photo
      image = Vips::Image.gaussnoise(3600, 2700, sigma: 55, mean: 128).cast(:uchar)
      file = Tempfile.new([ "celular", ".jpg" ])
      file.binmode
      image.bandjoin([ image, image ]).write_to_file(file.path, Q: 100)
      file
    end

    it "accepts a phone photo above the 5 MB limit and stores a reduced copy" do
      file = big_phone_photo
      expect(file.size).to be > Product::MAIN_IMAGE_MAX_BYTES

      expect do
        post seller_products_path, params: {
          product: { name: "Peça com foto grande", sku: "BIGPHOTO-001", price: "40,00", currency: "BRL", stock_quantity: 1,
                     main_image: Rack::Test::UploadedFile.new(file.path, "image/jpeg", original_filename: "IMG_0001.jpg") }
        }
      end.to change(seller.products, :count).by(1)

      stored = seller.products.find_by!(sku: "BIGPHOTO-001").main_image.blob
      expect(stored.byte_size).to be < Product::MAIN_IMAGE_MAX_BYTES
      expect(stored.filename.to_s).to eq("IMG_0001.jpg")
      expect(Vips::Image.new_from_buffer(stored.download, "").size.max).to be <= Images::Optimizer::MAX_DIMENSION
    end

    it "also reduces the gallery photos added later" do
      file = big_phone_photo

      patch seller_product_path(own_product), params: {
        product: { images: [ Rack::Test::UploadedFile.new(file.path, "image/jpeg", original_filename: "galeria.jpg") ] }
      }

      expect(own_product.images.reload.count).to eq(1)
      expect(own_product.images.first.blob.byte_size).to be < Product::MAIN_IMAGE_MAX_BYTES
    end

    it "still rejects a file above the raw limit" do
      file = Tempfile.new([ "enorme", ".jpg" ])
      file.binmode
      file.write("0" * (Images::Optimizer::RAW_UPLOAD_MAX_BYTES + 1))
      file.flush

      expect do
        post seller_products_path, params: {
          product: { name: "Peça enorme", sku: "HUGE-001", price: "40,00", currency: "BRL", stock_quantity: 1,
                     main_image: Rack::Test::UploadedFile.new(file.path, "image/jpeg") }
        }
      end.not_to change(seller.products, :count)
    end
  end

  it "cannot publish while seller approval is pending" do
    seller.update!(status: :pending, approved_at: nil)

    patch publish_seller_product_path(own_product)

    expect(response).to redirect_to(seller_product_path(own_product))
    expect(own_product.reload).to be_draft

    follow_redirect!
    expect(response.body).to include('class="app-flash app-flash--error"')
    expect(response.body).to include("Algo deu errado", "Fechar mensagem de erro")
  end

  it "exposes weight and dimension fields on the product form" do
    get new_seller_product_path

    expect(response.body).to include("product_weight_grams", "product_length_cm", "product_width_cm", "product_height_cm")
  end

  it "shows and saves the product delivery configuration" do
    get edit_seller_product_path(own_product)

    expect(response.body).to include("Frete deste produto")
    expect(response.body).to include("Permitir retirada gratuita deste produto")

    patch seller_product_path(own_product), params: { product: {
      fixed_shipping: "20,00", fixed_shipping_estimated_days: "8", local_pickup_enabled: "1"
    } }

    own_product.reload
    expect(own_product.fixed_shipping_cents).to eq(2000)
    expect(own_product.fixed_shipping_estimated_days).to eq(8)
    expect(own_product).to be_local_pickup_enabled

    follow_redirect!
    expect(response.body).to include('data-controller="flash"')
    expect(response.body).to include("Sucesso!", "Produto atualizado com sucesso.", "Fechar mensagem de sucesso")
  end

  it "rejects an incomplete product delivery configuration" do
    patch seller_product_path(own_product), params: { product: {
      fixed_shipping: "20,00", fixed_shipping_estimated_days: ""
    } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(own_product.reload.fixed_shipping_cents).to be_nil
  end

  it "publishes once name, price and shipping dimensions are set" do
    own_product.update!(weight_grams: 200, length_cm: 10, width_cm: 10, height_cm: 10)

    patch publish_seller_product_path(own_product)

    expect(response).to redirect_to(seller_product_path(own_product))
    expect(own_product.reload).to be_active
  end

  it "accepts weight and dimensions through the update form" do
    patch seller_product_path(own_product), params: { product: { weight_grams: "200", length_cm: "10", width_cm: "10", height_cm: "10" } }

    own_product.reload
    expect(own_product.weight_grams).to eq(200)
    expect(own_product.length_cm).to eq(10)
    expect(own_product.width_cm).to eq(10)
    expect(own_product.height_cm).to eq(10)
  end

  it "updates the product's free shipping toggle" do
    patch seller_product_path(own_product), params: { product: { free_shipping: "1" } }

    expect(own_product.reload.free_shipping).to be(true)
  end

  it "discontinues the selected owned products in bulk" do
    own_product.update!(status: :active)
    other_active = Product.create!(seller: seller, name: "Caneca própria", sku: "OWN-003", price_cents: 3_000, stock_quantity: 2, status: :active)

    patch bulk_discontinue_seller_products_path, params: { product_ids: [ own_product.id, other_active.id ] }

    expect(own_product.reload).to be_discontinued
    expect(other_active.reload).to be_discontinued
    expect(response).to redirect_to(seller_products_path)
  end

  it "skips products that cannot transition to discontinued and reports how many were skipped" do
    own_product.update!(status: :active)
    draft_product = Product.create!(seller: seller, name: "Rascunho", sku: "OWN-004", price_cents: 3_000, stock_quantity: 2)

    patch bulk_discontinue_seller_products_path, params: { product_ids: [ own_product.id, draft_product.id ] }

    expect(own_product.reload).to be_discontinued
    expect(draft_product.reload).to be_draft

    follow_redirect!
    expect(response.body).to include("1 produto(s) descontinuado(s). 1 não puderam ser alterados")
  end

  it "does not let a seller discontinue another seller's product by id" do
    other_product.update!(status: :active)

    patch bulk_discontinue_seller_products_path, params: { product_ids: [ other_product.id ] }

    expect(other_product.reload).to be_active
  end

  it "unpublishes the selected owned products in bulk" do
    own_product.update!(status: :active)
    other_active = Product.create!(seller: seller, name: "Caneca própria", sku: "OWN-005", price_cents: 3_000, stock_quantity: 2, status: :active)

    patch bulk_unpublish_seller_products_path, params: { product_ids: [ own_product.id, other_active.id ] }

    expect(own_product.reload).to be_draft
    expect(other_active.reload).to be_draft
    expect(response).to redirect_to(seller_products_path)
  end

  it "skips products that cannot be unpublished and reports how many were skipped" do
    own_product.update!(status: :active)
    discontinued_product = Product.create!(seller: seller, name: "Fora de linha", sku: "OWN-006", price_cents: 3_000, stock_quantity: 2, status: :discontinued)

    patch bulk_unpublish_seller_products_path, params: { product_ids: [ own_product.id, discontinued_product.id ] }

    expect(own_product.reload).to be_draft
    expect(discontinued_product.reload).to be_discontinued

    follow_redirect!
    expect(response.body).to include("1 produto(s) escondido(s). 1 não puderam ser alterados")
  end

  it "does not let a seller unpublish another seller's product by id" do
    other_product.update!(status: :active)

    patch bulk_unpublish_seller_products_path, params: { product_ids: [ other_product.id ] }

    expect(other_product.reload).to be_active
  end

  describe "required field markers" do
    it "marks name and price as required with the red-border controller" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("form[data-controller='required-fields'][novalidate]")).to be_present
      %w[product_name product_price].each do |id|
        field = doc.at_css("##{id}")
        expect(field["required"]).to be_present
        expect(field["data-required-fields-target"]).to eq("field")
        expect(doc.at_css("label[for='#{id}'] [data-required-fields-target='marker']")).to be_present
      end
    end

    it "hides the production time markers unless the product is made to order" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      %w[product_production_time_min_days product_production_time_max_days].each do |id|
        expect(doc.at_css("##{id}")["required"]).to be_nil
        expect(doc.at_css("label[for='#{id}'] [data-required-fields-target='marker']")["hidden"]).to be_present
      end
    end

    it "marks the production time as required for a made to order product" do
      own_product.update!(availability_type: :made_to_order, production_time_min_days: 3, production_time_max_days: 7)

      get edit_seller_product_path(own_product)

      doc = Nokogiri::HTML(response.body)
      %w[product_production_time_min_days product_production_time_max_days].each do |id|
        expect(doc.at_css("##{id}")["required"]).to be_present
        expect(doc.at_css("label[for='#{id}'] [data-required-fields-target='marker']")["hidden"]).to be_nil
      end
    end

    it "labels the category as optional and explains why to pick one" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("label[for='product_category_id']").text).to eq("Categoria (opcional)")
      expect(doc.at_css("#product_category_id")["required"]).to be_nil
      expect(response.body).to include("ajuda o cliente a encontrar o seu produto")
    end

    it "does not mark the SKU as required" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#product_sku")["required"]).to be_nil
      expect(doc.at_css("label[for='product_sku'] [data-required-fields-target='marker']")).to be_nil
    end

    it "marks weight and dimensions as required to publish, without blocking the save" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      %w[product_weight_grams product_length_cm product_width_cm product_height_cm].each do |id|
        field = doc.at_css("##{id}")
        expect(field["required"]).to be_nil
        expect(field["data-publish-required"]).to eq("true")
        expect(doc.at_css("label[for='#{id}'] [data-required-fields-target='marker']")["hidden"]).to be_nil
      end
      expect(response.body).to include("obrigatórios para <strong>publicar</strong>")
    end
  end
end
