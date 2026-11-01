# frozen_string_literal: true

require "rails_helper"

# Fora das specs rswag: o 401 com token inválido já está documentado lá; aqui
# ficam os casos que não são contrato da API, mas regra de acesso.
RSpec.describe "API v1 authentication", type: :request do
  ENDPOINTS = %w[/api/v1/products /api/v1/sellers /api/v1/categories].freeze

  it "recusa chamada sem token em todos os endpoints" do
    ENDPOINTS.each do |path|
      get path

      expect(response).to have_http_status(:unauthorized), "#{path} respondeu #{response.status}"
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      expect(JSON.parse(response.body)).to eq("error" => "unauthorized")
    end
  end

  it "recusa o token revogado" do
    client = ApiClient.create!(name: "Cliente revogado")
    client.revoke!

    get "/api/v1/products", headers: { "Authorization" => "Bearer #{client.token}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "não aceita o token em HTTP Basic, só como Bearer" do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("cliente", api_token)

    get "/api/v1/products", headers: { "Authorization" => credentials }

    expect(response).to have_http_status(:unauthorized)
  end

  it "não aceita a sessão do admin no lugar do token" do
    sign_in_as(User.create!(email_address: "admin-api@eloshop.test", password: "password123"))

    get "/api/v1/products"

    expect(response).to have_http_status(:unauthorized)
  end

  it "responde ao token válido e registra o uso" do
    client = ApiClient.create!(name: "Cliente ativo")

    get "/api/v1/products", headers: { "Authorization" => "Bearer #{client.token}" }

    expect(response).to have_http_status(:ok)
    expect(client.reload.last_used_at).to be_present
  end
end
