# frozen_string_literal: true

require "rails_helper"

# O ETag vem do corpo da resposta (Rack::ETag, no middleware padrão do Rails),
# não de `updated_at`: `available_for_purchase` depende de variante, estoque,
# ateliê, categoria e da abertura das vendas, e nenhum desses toca o produto.
# Um ETag montado a partir dos registros erraria em silêncio quando um deles
# mudasse; o do corpo muda sempre que a resposta muda. O servidor ainda monta
# a resposta — o que se economiza é a transferência.
RSpec.describe "API v1 conditional GET", type: :request do
  let!(:product) { Product.create!(seller: approved_seller, name: "Vaso do ETag", sku: "ETAG-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }

  it "responde 304 sem corpo quando o cliente já tem a versão atual" do
    get "/api/v1/products", headers: api_headers
    etag = response.headers["ETag"]

    expect(etag).to be_present
    expect(response.headers["Cache-Control"]).to include("private")

    get "/api/v1/products", headers: api_headers("If-None-Match" => etag)

    expect(response).to have_http_status(:not_modified)
    expect(response.body).to be_empty
  end

  it "responde 200 com ETag novo quando a disponibilidade muda sem tocar o produto" do
    get "/api/v1/products", headers: api_headers
    etag = response.headers["ETag"]

    PlatformSetting.instance.update!(sales_opened_at: nil)
    get "/api/v1/products", headers: api_headers("If-None-Match" => etag)

    expect(response).to have_http_status(:ok)
    expect(response.headers["ETag"]).not_to eq(etag)
  end
end
