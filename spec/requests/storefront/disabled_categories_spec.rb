# frozen_string_literal: true

require "rails_helper"

# Desabilitar uma categoria tem que tirar os produtos dela do ar em TODA
# superfície pública — não basta sumir da navegação, senão a URL direta e a
# busca continuam vendendo.
RSpec.describe "Disabled categories", type: :request do
  let(:disabled) { Category.create!(name: "Casa desabilitada", active: false) }
  let(:child) { disabled.children.create!(name: "Decoração sob desabilitada") }
  let(:enabled) { Category.create!(name: "Moda ativa") }

  def create_product(name:, category:)
    Product.create!(seller: approved_seller, name: name, sku: "DIS-#{SecureRandom.hex(4)}",
      price_cents: 4_990, stock_quantity: 3, currency: "BRL", status: :active, category: category)
  end

  it "hides the product from the catalog" do
    hidden = create_product(name: "Vaso escondido", category: disabled)
    shown = create_product(name: "Bolsa visível", category: enabled)

    get products_path

    expect(response.body).not_to include(hidden.name)
    expect(response.body).to include(shown.name)
  end

  it "hides a product in a subcategory of the disabled one" do
    hidden = create_product(name: "Quadro herdado", category: child)

    get products_path

    expect(response.body).not_to include(hidden.name)
  end

  it "hides the product from search results" do
    hidden = create_product(name: "Vaso buscável", category: disabled)

    get products_path, params: { q: "buscável" }

    expect(response.body).not_to include(hidden.name)
  end

  it "returns 404 on the product page reached by direct URL" do
    hidden = create_product(name: "Vaso por URL", category: disabled)

    get product_path(hidden.seller, hidden.slug)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when filtering by the disabled category" do
    get products_path, params: { category: disabled.slug }

    expect(response).to have_http_status(:not_found)
  end

  it "drops the category from the home page" do
    disabled
    enabled

    get root_path

    expect(response.body).not_to include(disabled.name)
    expect(response.body).to include(enabled.name)
  end

  it "drops the category and its products from the sitemap" do
    hidden = create_product(name: "Vaso do sitemap", category: disabled)

    get sitemap_path(format: :xml)

    expect(response.body).not_to include(hidden.slug)
    expect(response.body).not_to include(disabled.slug)
  end

  it "hides the product from the public API" do
    hidden = create_product(name: "Vaso da API", category: disabled)

    get "/api/v1/products", headers: { "ACCEPT" => "application/json" }

    expect(response.body).not_to include(hidden.name)
  end

  it "shows everything again once the category is re-enabled" do
    hidden = create_product(name: "Vaso que retorna", category: disabled)

    disabled.update!(active: true)
    get products_path

    expect(response.body).to include(hidden.name)
  end
end
