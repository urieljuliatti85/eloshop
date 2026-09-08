# frozen_string_literal: true

require "rails_helper"

# Separada das specs rswag de propósito: aquelas declaram `produces json` e
# alimentam o `swagger.yaml`, então um caso de "cliente pedindo HTML" não
# pertence à documentação da API — mas precisa de teste, porque foi
# justamente o caso que ninguém cobria.
RSpec.describe "API v1 content negotiation", type: :request do
  # O que o Chrome manda ao colar a URL na barra de endereços.
  BROWSER_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

  # Sem `defaults: { format: :json }` na rota, o Rails procurava uma view
  # `.html` que nunca existiu e devolvia 406 com a página de exceção do
  # Rails — HTML, não JSON — justo para quem estava conhecendo a API.
  it "serves JSON to a browser asking for HTML" do
    get "/api/v1/products", headers: { "Accept" => BROWSER_ACCEPT }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect { JSON.parse(response.body) }.not_to raise_error
  end

  it "serves JSON on every public endpoint regardless of Accept" do
    %w[/api/v1/products /api/v1/sellers /api/v1/categories].each do |path|
      get path, headers: { "Accept" => BROWSER_ACCEPT }

      expect(response).to have_http_status(:ok), "#{path} respondeu #{response.status}"
      expect(response.media_type).to eq("application/json"), "#{path} devolveu #{response.media_type}"
    end
  end

  # Clientes de API já funcionavam antes desta mudança; a garantia é que
  # continuem funcionando.
  it "keeps serving JSON to clients that send no Accept or a wildcard" do
    [ nil, "*/*", "application/json" ].each do |accept|
      get "/api/v1/products", headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
    end
  end

  # O 404 da API é JSON (`BaseController`); pedir HTML não pode transformá-lo
  # na página de erro do Rails.
  it "answers a missing record with JSON even when HTML is requested" do
    get "/api/v1/sellers/nao-existe", headers: { "Accept" => BROWSER_ACCEPT }

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq("error" => "not_found")
  end
end
