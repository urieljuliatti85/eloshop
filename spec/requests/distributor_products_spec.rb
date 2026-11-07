# frozen_string_literal: true

require "rails_helper"

# Catálogo de insumos do distribuidor (ADR 007, Fase 26, PR B): as ações do
# catálogo do ateliê por subclasse, com os campos do insumo (unidade, mínimo,
# faixas de desconto em %, material e técnica) e o escopo sempre pela sessão.
RSpec.describe "Distributor products", type: :request do
  def create_distributor(status: :pending)
    seller = Seller.create!(name: "Fios #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf,
      kind: "distributor", status: status, approved_at: (Time.current if status == :approved))
    user = User.create!(email_address: "insumos-#{SecureRandom.hex(3)}@example.com", password: "password123", role: :seller, seller: seller)
    accept_current_seller_terms(user)
    user
  end

  def sign_in_distributor(user)
    post distributor_login_path, params: { email_address: user.email_address, password: "password123" }
  end

  let(:user) { create_distributor }
  let(:distributor) { user.seller }
  let!(:cotton) { Material.find_or_create_by!(name: "Algodão") }
  let!(:crochet) { Technique.find_or_create_by!(name: "Crochê") }

  let(:supply_params) do
    { product: {
      name: "Fio de algodão cru", description: "Fio 100% algodão", price: "25,00", stock_quantity: "200",
      sale_unit: "pack", sale_unit_detail: "pacote com 100 g", min_order_quantity: "5",
      material_ids: [ cotton.id ], technique_ids: [ crochet.id ],
      price_tiers_attributes: {
        "0" => { min_quantity: "10", discount_percent: "10" },
        "1" => { min_quantity: "50", discount_percent: "18" },
        "2" => { min_quantity: "", discount_percent: "" }
      }
    } }
  end

  it "shows material category icons in the new supply form and the product list" do
    sign_in_distributor(user)
    get new_distributor_product_path

    expect(response.body).to include("Categoria de insumo / material", "Algodão", "Crochê", "<svg")

    post distributor_products_path, params: supply_params
    get distributor_products_path

    expect(response.body).to include("Fio de algodão cru", "Algodão", "Crochê", "<svg")
  end

  it "creates a supply with unit, minimum, tiers in percent and material/technique, ignoring blank tier rows" do
    sign_in_distributor(user)

    expect { post distributor_products_path, params: supply_params }.to change(distributor.products, :count).by(1)

    supply = distributor.products.last
    expect(response).to redirect_to(distributor_product_path(supply))
    expect(supply).to be_draft
    expect(supply).to be_sold_by_pack
    expect(supply.sale_unit_detail).to eq("pacote com 100 g")
    expect(supply.min_order_quantity).to eq(5)
    expect(supply.price_tiers.map { |tier| [ tier.min_quantity, tier.discount_bps ] }).to eq([ [ 10, 1_000 ], [ 50, 1_800 ] ])
    expect(supply.materials).to eq([ cotton ])
    expect(supply.techniques).to eq([ crochet ])

    follow_redirect!
    expect(response.body).to include("R$ 22,50", "R$ 20,50", "por pacote", "Algodão", "Crochê")
  end

  it "accepts a decimal percent with comma and shows it back the same way" do
    sign_in_distributor(user)

    post distributor_products_path, params: supply_params.deep_merge(product: { price_tiers_attributes: { "0" => { discount_percent: "10,5" } } })

    supply = distributor.products.last
    expect(supply.price_tiers.first.discount_bps).to eq(1_050)
    get edit_distributor_product_path(supply)
    expect(response.body).to include('value="10,5"')
  end

  it "refuses tiers out of order or above 50% and keeps the form" do
    sign_in_distributor(user)

    [ { "0" => { min_quantity: "10", discount_percent: "20" }, "1" => { min_quantity: "50", discount_percent: "5" } },
      { "0" => { min_quantity: "10", discount_percent: "60" } },
      { "0" => { min_quantity: "3", discount_percent: "10" } } ].each do |tiers|
      expect do
        post distributor_products_path, params: supply_params.deep_merge(product: { price_tiers_attributes: tiers.merge("1" => tiers.fetch("1", { min_quantity: "", discount_percent: "" })) })
      end.not_to change(Product, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Salvar insumo")
    end
  end

  it "edits several tiers together and removes one" do
    sign_in_distributor(user)
    post distributor_products_path, params: supply_params
    supply = distributor.products.last
    first, second = supply.price_tiers.to_a

    patch distributor_product_path(supply), params: { product: { price_tiers_attributes: {
      "0" => { id: first.id, min_quantity: "10", discount_percent: "25" },
      "1" => { id: second.id, min_quantity: "50", discount_percent: "30" }
    } } }
    expect(supply.reload.price_tiers.map(&:discount_bps)).to eq([ 2_500, 3_000 ])

    patch distributor_product_path(supply), params: { product: { price_tiers_attributes: { "0" => { id: first.id, _destroy: "1" } } } }
    expect(supply.reload.price_tiers.map(&:min_quantity)).to eq([ 50 ])
  end

  it "ignores seller, status, availability, category and personalization sent by the browser" do
    sign_in_distributor(user)
    other = create_distributor.seller

    post distributor_products_path, params: supply_params.deep_merge(product: {
      seller_id: other.id, status: "active", availability_type: "one_of_a_kind", category_id: Category.first&.id
    })

    supply = Product.order(:id).last
    expect(supply.seller).to eq(distributor)
    expect(supply).to be_draft
    expect(supply).to be_availability_type_standard
    expect(supply.category_id).to be_nil
  end

  it "uploads photos through the same optimized path as the atelier" do
    sign_in_distributor(user)

    post distributor_products_path, params: supply_params.deep_merge(product: {
      main_image: fixture_file_upload("sample.png", "image/png"), images: [ fixture_file_upload("sample.png", "image/png") ]
    })

    supply = distributor.products.last
    expect(supply.main_image).to be_attached
    expect(supply.images.count).to eq(1)

    delete distributor_product_product_image_path(supply, supply.images.first)
    expect(response).to redirect_to(distributor_product_path(supply))
    expect(supply.reload.images.count).to eq(0)
  end

  describe "publishing" do
    let(:ready_params) do
      supply_params.deep_merge(product: { weight_grams: "120", length_cm: "10", width_cm: "10", height_cm: "5",
        fixed_shipping: "18,00", fixed_shipping_estimated_days: "7" })
    end

    it "asks for the showcase release first, then publishes without a category" do
      sign_in_distributor(user)
      post distributor_products_path, params: ready_params
      supply = distributor.products.last

      patch publish_distributor_product_path(supply)
      expect(flash[:alert]).to include("O armarinho precisa estar aprovado ou liberado na vitrine")
      expect(supply.reload).to be_draft

      distributor.showcase!
      patch publish_distributor_product_path(supply)
      expect(supply.reload).to be_active
      expect(Product.publicly_visible).not_to include(supply), "insumo nunca entra na vitrine de peças"
    end

    it "warns on the page when the minimum is above the stock" do
      sign_in_distributor(user)
      post distributor_products_path, params: ready_params.deep_merge(product: { stock_quantity: "3", min_order_quantity: "5", price_tiers_attributes: { "0" => { min_quantity: "", discount_percent: "" }, "1" => { min_quantity: "", discount_percent: "" } } })

      get distributor_product_path(distributor.products.last)
      expect(response.body).to include("Indisponível para compra", "a quantidade mínima (5) é maior que o estoque (3)")
    end
  end

  describe "isolation" do
    it "never shows or changes another distributor's supply" do
      other = create_distributor.seller
      foreign = other.products.create!(name: "Fio alheio", price_cents: 1_000, stock_quantity: 5)
      sign_in_distributor(user)

      get distributor_product_path(foreign)
      expect(response).to have_http_status(:not_found)
      patch distributor_product_path(foreign), params: { product: { name: "Tomado" } }
      expect(response).to have_http_status(:not_found)
      patch publish_distributor_product_path(foreign)
      expect(response).to have_http_status(:not_found)
      delete distributor_product_product_image_path(foreign, 1)
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.name).to eq("Fio alheio")

      get distributor_products_path
      expect(response.body).not_to include("Fio alheio")
    end

    it "keeps the atelier catalog closed to the distributor and the supply catalog closed to the atelier" do
      sign_in_distributor(user)
      get seller_products_path
      expect(response).to redirect_to(distributor_root_path)
      post seller_products_path, params: { product: { name: "Peça" } }
      expect(response).to redirect_to(distributor_root_path)
      delete distributor_logout_path

      post seller_login_path, params: { email_address: User.find_by!(seller: approved_seller).email_address, password: "password123" }
      get distributor_products_path
      expect(response).to redirect_to(seller_root_path)
      post distributor_products_path, params: supply_params
      expect(response).to redirect_to(seller_root_path)
      expect(approved_seller.products.where(name: "Fio de algodão cru")).to be_empty
    end
  end
end
