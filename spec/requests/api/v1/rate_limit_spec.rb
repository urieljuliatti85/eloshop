# frozen_string_literal: true

require "rails_helper"

# Fora das specs rswag: o 429 está documentado lá; aqui ficam as regras de
# quem divide a cota e de quando ela volta.
RSpec.describe "API v1 rate limit", type: :request do
  let(:limit) { Api::V1::BaseController::RATE_LIMIT }

  def exhaust_quota(token)
    limit.times do
      get "/api/v1/categories", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end
  end

  it "recusa a chamada além da cota com 429, Retry-After e erro em JSON" do
    exhaust_quota(api_token)

    get "/api/v1/products", headers: api_headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to eq(Api::V1::BaseController::RATE_LIMIT_WINDOW.to_i.to_s)
    expect(JSON.parse(response.body)).to eq("error" => "rate_limited")
  end

  it "conta por cliente: esgotar a cota de um não afeta outro" do
    exhaust_quota(api_token)
    other = ApiClient.create!(name: "Outro cliente da cota")

    get "/api/v1/products", headers: { "Authorization" => "Bearer #{other.token}" }

    expect(response).to have_http_status(:ok)
  end

  it "renova a cota depois da janela" do
    exhaust_quota(api_token)

    travel Api::V1::BaseController::RATE_LIMIT_WINDOW + 1.second do
      get "/api/v1/products", headers: api_headers
    end

    expect(response).to have_http_status(:ok)
  end

  it "não conta chamada sem token válido na cota de ninguém" do
    (limit + 1).times { get "/api/v1/products", headers: { "Authorization" => "Bearer token-invalido" } }

    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/products", headers: api_headers
    expect(response).to have_http_status(:ok)
  end
end
