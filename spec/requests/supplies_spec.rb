# frozen_string_literal: true

require "rails_helper"

# Vitrine de insumos (ADR 007, Fase 26, PR C): /insumos, a loja
# /distribuidores/:slug e a página /distribuidores/:slug/insumos/:produto.
# Mostra só `Product.supply_visible`; a vitrine de peças e a de insumos nunca
# se misturam, nos dois sentidos. Compra só na Fase 27.
RSpec.describe "Supply storefront", type: :request do
  def distributor(status: :approved, showcased: false, hidden: false, issues_invoices: true)
    Seller.create!(name: "Fios #{SecureRandom.hex(3)}", owner_full_name: "Dona", cpf: generate_valid_cpf, kind: "distributor",
      status: status, approved_at: (Time.current if status == :approved), showcased_at: (Time.current if showcased),
      hidden_at: (Time.current if hidden), issues_invoices: issues_invoices)
  end

  def supply(seller, name: "Fio #{SecureRandom.hex(3)}", status: :active, **attributes)
    seller.products.create!(name: name, price_cents: 2_500, stock_quantity: 100, status: status, sale_unit: "pack",
      sale_unit_detail: "pacote com 100 g", **attributes)
  end

  let(:fios) { distributor }
  let!(:cotton) { Material.find_or_create_by!(name: "Algodão") }
  let!(:wool) { Material.find_or_create_by!(name: "Lã") }
  let!(:crochet) { Technique.find_or_create_by!(name: "Crochê") }

  it "lists published supplies of listed distributors, never an atelier piece, and stays out of Google" do
    cotton_yarn = supply(fios, name: "Fio de algodão cru")
    draft = supply(fios, name: "Fio rascunho", status: :draft)
    released = supply(distributor(status: :pending, showcased: true), name: "Fio liberado")
    hidden = supply(distributor(hidden: true), name: "Fio escondido")
    unreleased = supply(distributor(status: :pending), name: "Fio pendente")
    piece = approved_seller.products.create!(name: "Vaso de cerâmica azul", price_cents: 9_000, stock_quantity: 2, status: :active)

    get supplies_path

    expect(response.body).to include(cotton_yarn.name, released.name, "R$ 25,00", "por pacote", 'name="robots" content="noindex"')
    expect(response.body).not_to include(draft.name, hidden.name, unreleased.name, piece.name)
  end

  it "filters by material and technique, offering only those with supplies" do
    cotton_yarn = supply(fios, name: "Fio de algodão cru", materials: [ cotton ], techniques: [ crochet ])
    wool_yarn = supply(fios, name: "Fio de lã merino", materials: [ wool ])

    get supplies_path(material: "algodao")
    expect(response.body).to include(cotton_yarn.name)
    expect(response.body).not_to include(wool_yarn.name)

    get supplies_path(tecnica: "croche")
    expect(response.body).to include(cotton_yarn.name)
    expect(response.body).not_to include(wool_yarn.name)

    get supplies_path
    expect(response.body).to include(supplies_path(material: "la"), supplies_path(tecnica: "croche"))
  end

  it "says the first supplies are coming when there is none" do
    get supplies_path

    expect(response.body).to include("Os primeiros insumos chegam em breve")
  end

  it "shows the supply page with the tier table, minimum, shipping limit and invoice declaration, without buying" do
    yarn = supply(fios, name: "Fio de algodão cru", min_order_quantity: 5)
    yarn.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)
    yarn.price_tiers.create!(min_quantity: 50, discount_bps: 1_800)

    get supply_path(fios.slug, yarn.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("R$ 25,00", "R$ 22,50", "R$ 20,50", "5 pacotes", "Pacote com 100 g",
      "Até 30 kg por pedido", "o distribuidor emite", "Vendas de insumos em breve", 'name="robots" content="noindex"')
    expect(response.body).not_to include("feito à mão", cart_items_path)
  end

  it "answers 404 for a draft, a hidden or unreleased distributor, and a supply under another distributor" do
    other = distributor
    draft = supply(fios, status: :draft)
    hidden = supply(distributor(hidden: true))
    unreleased = supply(distributor(status: :pending))
    yarn = supply(fios)

    [ supply_path(fios.slug, draft.slug), supply_path(hidden.seller.slug, hidden.slug),
      supply_path(unreleased.seller.slug, unreleased.slug), supply_path(other.slug, yarn.slug) ].each do |path|
      get path
      expect(response).to have_http_status(:not_found), "#{path} answered #{response.status}"
    end
  end

  it "shows the distributor store with its published supplies, and 404 for an atelier or an unlisted distributor" do
    yarn = supply(fios, name: "Fio publicado")
    draft = supply(fios, name: "Fio guardado", status: :draft)

    get distributor_store_path(fios.slug)
    expect(response.body).to include(fios.name, yarn.name, "Nota fiscal: emite")
    expect(response.body).not_to include(draft.name)

    [ approved_seller.slug, distributor(status: :pending).slug, distributor(status: :suspended).slug ].each do |slug|
      get distributor_store_path(slug)
      expect(response).to have_http_status(:not_found), "/distribuidores/#{slug} answered #{response.status}"
    end
  end

  it "links the distributors list to each store" do
    fios

    get distributors_path

    expect(response.body).to include(distributor_store_path(fios.slug), supplies_path)
  end

  it "keeps supplies out of the piece catalog and pieces out of the supply catalog" do
    yarn = supply(fios, name: "Fio de algodão cru")
    piece = approved_seller.products.create!(name: "Vaso de cerâmica azul", price_cents: 9_000, stock_quantity: 2, status: :active)

    get products_path
    expect(response.body).to include(piece.name)
    expect(response.body).not_to include(yarn.name)

    get supplies_path
    expect(response.body).to include(yarn.name)
    expect(response.body).not_to include(piece.name)

    get supply_path(approved_seller.slug, piece.slug)
    expect(response).to have_http_status(:not_found)
    get product_path(fios.slug, yarn.slug)
    expect(response).to have_http_status(:not_found)
  end

  it "still refuses a supply in the cart until the purchase phase" do
    yarn = supply(fios)

    post cart_items_path, params: { product_id: yarn.id, quantity: 10 }

    expect(CartItem.where(product: yarn)).to be_empty
  end
end
