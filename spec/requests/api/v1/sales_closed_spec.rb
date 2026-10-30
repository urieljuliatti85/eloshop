# frozen_string_literal: true

require "rails_helper"

# Pré-cadastro: com as vendas da plataforma fechadas a loja recusa carrinho e
# checkout, então a API não pode anunciar peça disponível para compra — mesmo
# que a peça em si seja vendável e continue listada.
RSpec.describe "API v1 com as vendas fechadas", type: :request do
  let!(:product) { Product.create!(seller: approved_seller, name: "Vaso do pré-cadastro", sku: "PRECAD-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }

  def available_for_purchase_in_list
    get "/api/v1/products", headers: api_headers
    JSON.parse(response.body)["products"].find { |p| p["slug"] == product.slug }["available_for_purchase"]
  end

  it "lista a peça, mas não como disponível para compra" do
    PlatformSetting.instance.update!(sales_opened_at: nil)

    expect(available_for_purchase_in_list).to be(false)

    get "/api/v1/sellers/#{approved_seller.slug}/products/#{product.slug}", headers: api_headers
    expect(JSON.parse(response.body)["available_for_purchase"]).to be(false)
  end

  it "volta a anunciar a peça quando as vendas abrem" do
    expect(available_for_purchase_in_list).to be(true)
  end
end
