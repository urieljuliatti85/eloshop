# frozen_string_literal: true

require "rails_helper"

# Fora das specs rswag: o 400 está documentado lá; aqui ficam as entradas
# malformadas que antes chegavam ao domínio e respondiam 500.
RSpec.describe "API v1 parâmetros inválidos da listagem", type: :request do
  let!(:product) { Product.create!(seller: approved_seller, name: "Vaso dos parâmetros", sku: "PARAMS-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }

  {
    "page[]=1" => "page",
    "page[a]=1" => "page",
    "page=abc" => "page",
    "page=0" => "page",
    "page=-5" => "page",
    "page=0x2" => "page",
    "category[a]=x" => "category",
    "category[]=x" => "category",
    "seller[]=x" => "seller",
    "q[]=vaso" => "q",
    "availability[]=standard" => "availability",
    "availability=in_stock" => "availability"
  }.each do |query, parameter|
    it "responde 400 para #{query}" do
      get "/api/v1/products?#{query}", headers: api_headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "invalid_parameter", "parameter" => parameter)
    end
  end

  it "devolve lista vazia, sem erro, para página muito além da última" do
    get "/api/v1/products?page=99999999999999999999", headers: api_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["products"]).to eq([])
    expect(body["total_count"]).to be_positive
  end

  it "trata page e filtros vazios como ausentes" do
    get "/api/v1/products?page=&q=&availability=", headers: api_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["products"].map { |p| p["slug"] }).to include(product.slug)
  end
end
