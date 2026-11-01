# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin API clients", type: :request do
  let(:admin) { User.create!(email_address: "chefe-api@eloshop.test", password: "password123") }

  describe "autorização" do
    it "exige admin em todas as ações" do
      client = ApiClient.create!(name: "Parceiro")

      get admin_api_clients_path
      expect(response).to redirect_to(new_session_path)

      post admin_api_clients_path, params: { api_client: { name: "Intruso" } }
      expect(response).to redirect_to(new_session_path)

      patch revoke_admin_api_client_path(client)
      expect(response).to redirect_to(new_session_path)

      expect(ApiClient.where(name: "Intruso")).to be_empty
      expect(client.reload).not_to be_revoked
    end

    it "não deixa o vendedor entrar" do
      sign_in_as(approved_seller.users.first)

      post admin_api_clients_path, params: { api_client: { name: "Vendedor" } }

      expect(response).to redirect_to(new_session_path)
      expect(ApiClient.where(name: "Vendedor")).to be_empty
    end
  end

  describe "com o admin logado" do
    before { sign_in_as(admin) }

    it "lista clientes com situação e último uso" do
      ApiClient.create!(name: "Parceiro ativo")
      ApiClient.create!(name: "Parceiro antigo").revoke!

      get admin_api_clients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Parceiro ativo", "Parceiro antigo", "Revogado em", "Nunca")
    end

    it "mostra o token uma vez, sem cache, e ele vale na API" do
      post admin_api_clients_path, params: { api_client: { name: "Parceiro novo" } }

      expect(response).to have_http_status(:created)
      expect(response.headers["Cache-Control"]).to include("no-store")
      token = response.body[/id="api_client_token" type="text" value="([^"]+)"/, 1]
      expect(token).to be_present
      expect(ApiClient.find_by!(name: "Parceiro novo").token_digest).to eq(ApiClient.digest(token))

      get admin_api_clients_path
      expect(response.body).not_to include(token)

      get "/api/v1/categories", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end

    it "recusa nome em branco ou repetido" do
      ApiClient.create!(name: "Parceiro")

      post admin_api_clients_path, params: { api_client: { name: "parceiro" } }
      expect(response).to have_http_status(:unprocessable_content)

      post admin_api_clients_path, params: { api_client: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)

      expect(ApiClient.count).to eq(1)
    end

    it "revoga e o token para de valer na API" do
      client = ApiClient.create!(name: "Parceiro revogável")

      patch revoke_admin_api_client_path(client)

      expect(response).to redirect_to(admin_api_clients_path)
      expect(client.reload).to be_revoked

      get "/api/v1/categories", headers: { "Authorization" => "Bearer #{client.token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
