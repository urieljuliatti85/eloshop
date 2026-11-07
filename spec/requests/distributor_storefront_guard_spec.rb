# frozen_string_literal: true

require "rails_helper"

# Guarda da vitrine artesanal (ADR 007, "Vitrine fail-closed"): um
# distribuidor aprovado, na vitrine e com produto ativo não aparece em nenhuma
# superfície pública do catálogo de peças. A separação mora em
# `Seller.publicly_listed`, que alimenta `Product.publicly_visible`; esta spec
# cobre cada superfície para que um escopo novo, que não passe por ali, quebre
# aqui antes de mostrar insumo como peça artesanal.
RSpec.describe "Distributor storefront guard", type: :request do
  let!(:distributor) do
    Seller.create!(
      name: "Fios Atacado #{SecureRandom.hex(4)}", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf,
      kind: "distributor", status: :approved, approved_at: 1.day.ago, showcased_at: 1.day.ago
    )
  end
  let!(:supply) do
    Product.create!(seller: distributor, name: "Fio de algodão cru", sku: "FIO-001", price_cents: 2_500,
      stock_quantity: 40, currency: "BRL", status: :active)
  end
  let!(:piece) do
    Product.create!(seller: approved_seller, name: "Vaso de cerâmica azul", sku: "VASO-001", price_cents: 9_000,
      stock_quantity: 2, currency: "BRL", status: :active)
  end

  it "keeps the distributor's product out of the catalog, search and suggestions" do
    get products_path
    expect(response.body).to include(piece.name)
    expect(response.body).not_to include(supply.name)
    expect(response.body).not_to include(distributor.name)

    get products_path(q: "algodão")
    expect(response.body).not_to include(supply.name)

    get suggestions_products_path(q: "Fio")
    expect(response.body).not_to include(supply.name)
  end

  it "keeps the distributor's product out of the home page" do
    get root_path

    expect(response.body).not_to include(supply.name)
  end

  it "keeps the distributor out of /artesaos and without a public page there" do
    get sellers_path
    expect(response.body).to include(approved_seller.name)
    expect(response.body).not_to include(distributor.name)

    get seller_path(distributor)
    expect(response).to have_http_status(:not_found)
  end

  it "does not serve the distributor's product page under the artisan URL" do
    get product_path(distributor.slug, supply.slug)
    expect(response).to have_http_status(:not_found)

    get legacy_product_path(supply.slug)
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the distributor and its product out of the sitemap" do
    get sitemap_path

    expect(response.body).not_to include(supply.slug)
    expect(response.body).not_to include(distributor.slug)
  end

  it "keeps the distributor and its product out of the public API" do
    get api_v1_products_path, headers: api_headers
    expect(response.parsed_body.fetch("products").map { |product| product["slug"] }).not_to include(supply.slug)

    get api_v1_sellers_path, headers: api_headers
    expect(response.body).not_to include(distributor.slug)

    get api_v1_seller_path(distributor.slug), headers: api_headers
    expect(response).to have_http_status(:not_found)

    get api_v1_product_path(distributor.slug, supply.slug), headers: api_headers
    expect(response).to have_http_status(:not_found)
  end

  it "refuses the distributor's product in the cart, while an atelier's piece goes in" do
    post cart_items_path, params: { product_id: piece.id, quantity: 1 }
    expect(CartItem.where(product: piece)).to exist

    post cart_items_path, params: { product_id: supply.id, quantity: 1 }
    expect(CartItem.where(product: supply)).to be_empty
  end

  it "does not announce the opening of sales to the distributor" do
    expect { AnnounceSalesOpeningJob.perform_now }
      .not_to have_enqueued_job(NotifySellerOfSalesOpeningJob).with(distributor)
  end
end
