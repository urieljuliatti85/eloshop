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
  it "lists each product with its price, stock badge and a labeled checkbox" do
    own_product

    get seller_products_path

    expect(response.body).to include("R$ 50,00", "Estoque baixo: 2", "Selecionar Vaso próprio", "Sem foto")
  end

  it "shows an empty state with the way to create the first product" do
    get seller_products_path

    expect(response.body).to include("Sua primeira peça começa aqui.", new_seller_product_path)
    expect(response.body).not_to include("Selecionar todos")
  end

  it "does not issue more queries on the product list when products are added" do
    own_product
    get seller_products_path
    before = count_queries { get seller_products_path }

    3.times { |i| Product.create!(seller: seller, name: "Peça #{i}", sku: "MAIS-#{i}", price_cents: 4_000, stock_quantity: 5) }

    get seller_products_path
    after = count_queries { get seller_products_path }

    expect(after).to eq(before)
  end

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

  # A caixa do topo lista tudo; o erro também precisa estar no campo, porque
  # no celular a pessoa envia do fim do formulário e não vê o topo. Vem do
  # servidor, então aparece mesmo sem JavaScript — inclusive nas regras que o
  # navegador não confere (frete pela metade).
  it "shows each server-side error next to its field" do
    patch seller_product_path(own_product), params: { product: {
      name: "", fixed_shipping: "20,00", fixed_shipping_estimated_days: ""
    } }

    expect(response).to have_http_status(:unprocessable_entity)
    page = Nokogiri::HTML(response.body)
    %w[product_name product_fixed_shipping_estimated_days].each do |id|
      expect(page.at_css("##{id}")["aria-invalid"]).to eq("true")
      expect(page.at_css("##{id}")["aria-describedby"]).to eq("#{id}_error")
      expect(page.at_css("##{id}_error.field-error").text).to include("não pode ficar em branco")
    end
    expect(page.at_css("#product_sku")["aria-invalid"]).to be_nil
    expect(page.at_css("#product_sku_error")).to be_nil
  end

  it "explains a blank stock next to the field instead of saying it is not a number" do
    patch seller_product_path(own_product), params: { product: { stock_quantity: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#product_stock_quantity_error").text).to eq("precisa ser informado (use 0 se ainda não tiver peças prontas)")
    expect(response.body).not_to include("não é um número")
    expect(own_product.reload.stock_quantity).to eq(2)
  end

  # O navegador só conhece o limite da peça única se o campo vier com `max`; o
  # `required-fields` liga e desliga o atributo quando a disponibilidade muda.
  it "limits the stock field to 1 only for a one-of-a-kind piece" do
    get edit_seller_product_path(own_product)
    stock = Nokogiri::HTML(response.body).at_css("#product_stock_quantity")
    expect(stock["max"]).to be_nil
    expect(stock["data-max-when"]).to eq("one_of_a_kind")
    expect(stock["data-max-limit"]).to eq("1")

    own_product.update!(availability_type: :one_of_a_kind, stock_quantity: 1)
    get edit_seller_product_path(own_product)
    expect(Nokogiri::HTML(response.body).at_css("#product_stock_quantity")["max"]).to eq("1")
  end

  it "publishes once name, price, shipping dimensions and shipping price are set" do
    own_product.update!(weight_grams: 200, length_cm: 10, width_cm: 10, height_cm: 10, category: Category.create!(name: "Categoria publicar"),
      fixed_shipping_cents: 2000, fixed_shipping_estimated_days: 6)

    patch publish_seller_product_path(own_product)

    expect(response).to redirect_to(seller_product_path(own_product))
    expect(own_product.reload).to be_active
  end

  it "refuses to publish without a seller-defined shipping price" do
    own_product.update!(weight_grams: 200, length_cm: 10, width_cm: 10, height_cm: 10, category: Category.create!(name: "Categoria frete"))

    patch publish_seller_product_path(own_product)

    expect(own_product.reload).to be_draft
    expect(flash[:alert]).to include("frete")
  end

  describe "pending items to publish" do
    it "lists everything a draft still needs, with a link to complete it" do
      get seller_product_path(own_product)

      page = Nokogiri::HTML(response.body)
      card = page.at_css("section[aria-labelledby='publication-blockers-title']")
      expect(card.text).to include("Para publicar, falta:", "categoria", "peso", "frete")
      expect(card.at_css("a[href='#{edit_seller_product_path(own_product)}']").text).to eq("Completar cadastro")
      # O botão continua ativo: quem decide é o servidor.
      expect(page.at_css("form[action='#{publish_seller_product_path(own_product)}'] button")["disabled"]).to be_nil
    end

    it "hides the card once the draft is ready to publish" do
      own_product.update!(weight_grams: 200, length_cm: 10, width_cm: 10, height_cm: 10,
        category: Category.create!(name: "Categoria completa"), free_shipping: true)

      get seller_product_path(own_product)

      expect(response.body).not_to include("Para publicar, falta:")
    end

    it "does not show the card on a published product" do
      own_product.update_column(:status, "active")

      get seller_product_path(own_product)

      expect(response.body).not_to include("Para publicar, falta:")
    end
  end

  it "saves both shipping bands through the update form" do
    patch seller_product_path(own_product), params: { product: {
      fixed_shipping: "20,00", fixed_shipping_estimated_days: "5",
      fixed_shipping_interstate: "35,00", fixed_shipping_interstate_estimated_days: "9"
    } }

    own_product.reload
    expect([ own_product.fixed_shipping_cents, own_product.fixed_shipping_estimated_days ]).to eq([ 2000, 5 ])
    expect([ own_product.fixed_shipping_interstate_cents, own_product.fixed_shipping_interstate_estimated_days ]).to eq([ 3500, 9 ])
  end

  it "lists published products without a seller-defined shipping price" do
    own_product.update_columns(status: "active")

    get seller_products_path

    warning = Nokogiri::HTML(response.body).at_css("[data-products-without-shipping]")
    expect(warning).to be_present
    expect(warning.text).to include(own_product.name)
  end

  it "refuses to publish without a category" do
    own_product.update!(weight_grams: 200, length_cm: 10, width_cm: 10, height_cm: 10)

    patch publish_seller_product_path(own_product)

    expect(own_product.reload).to be_draft
    expect(flash[:alert]).to include("categoria")
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

  # O aviso de custo vem na página, não num confirm() — que navegador de
  # aplicativo responde "não" sem mostrar, desmarcando a caixa.
  it "explains the free shipping cost on the page instead of asking with confirm()" do
    get edit_seller_product_path(own_product)

    page = Nokogiri::HTML(response.body)
    checkbox = page.at_css("#product_free_shipping")
    expect(checkbox["data-action"]).to be_nil
    expect(response.body).not_to include("confirm-check")
    expect(page.at_css("[data-free-shipping-notice]").text).to include("Você assume o custo do envio deste produto")
  end

  # Fora do <label>: dentro dele o clique também acionaria o label e desfaria
  # a marcação.
  it "offers a Marcar/Desmarcar button for free shipping outside the checkbox label" do
    get edit_seller_product_path(own_product)

    page = Nokogiri::HTML(response.body)
    button = page.at_css("button[data-action='checkbox-toggle#toggle']")
    expect(button["type"]).to eq("button")
    expect(button["aria-controls"]).to eq("product_free_shipping")
    expect(button.text.squish).to include("Marcar frete grátis", "Desmarcar frete grátis")
    expect(button.ancestors("label")).to be_empty
    expect(page.at_css("#product_free_shipping")["data-checkbox-toggle-target"]).to eq("checkbox")
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

    # "Para publicar" em texto, e não o asterisco de "obrigatório para salvar":
    # o rascunho salva sem a categoria.
    it "marks the category as required to publish, and explains why" do
      get new_seller_product_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("label[for='product_category_id']").text).to start_with("Categoria")
      expect(doc.at_css("label[for='product_category_id'] [data-publish-marker]").text).to eq("Para publicar")
      expect(doc.at_css("label[for='product_category_id'] [data-required-fields-target='marker']")).to be_nil
      expect(doc.at_css("#product_category_id")["data-required-fields-target"]).to eq("field")
      expect(doc.at_css("#product_category_id")["data-publish-required"]).to be_present
      expect(doc.at_css("#product_category_id")["required"]).to be_nil
      expect(response.body).to include("É como o cliente encontra o seu produto.")
    end

    it "hides the production time fields unless the product is made to order" do
      get new_seller_product_path
      group = Nokogiri::HTML(response.body).at_css("#product_production_time_min_days").ancestors("[data-required-fields-target='group']").first
      expect(group.has_attribute?("hidden")).to be(true)

      own_product.update!(availability_type: :made_to_order, production_time_min_days: 3, production_time_max_days: 7)
      get edit_seller_product_path(own_product)
      group = Nokogiri::HTML(response.body).at_css("#product_production_time_min_days").ancestors("[data-required-fields-target='group']").first
      expect(group.has_attribute?("hidden")).to be(false)
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
        expect(doc.at_css("label[for='#{id}'] [data-publish-marker]")).to be_present
      end
      expect(response.body).to include("pode salvar como rascunho sem ele")
    end
  end
end
