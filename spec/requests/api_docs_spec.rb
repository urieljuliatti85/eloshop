# frozen_string_literal: true

require "rails_helper"

# O template padrão do rswag-ui inicializa o Swagger UI com <script> inline,
# que a CSP da aplicação bloqueia: a página abria em branco. O override em
# swagger/index.erb tira todo script inline; estes exemplos impedem que um
# `rails g rswag:ui:custom` ou upgrade da gem traga o original de volta.
RSpec.describe "API docs (Swagger UI)", type: :request do
  DOC_PATHS = [ "/api-docs/index.html", "/api-docs/v1/swagger.yaml" ].freeze

  # Entra o admin logado ou quem tem um ApiClient ativo, por HTTP Basic com o
  # token como senha. Os demais recebem 401 com o desafio Basic, para o
  # navegador abrir a janela de login.
  describe "acesso" do
    def basic_auth(token, user: "cliente")
      { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user, token) }
    end

    def expect_basic_challenge
      DOC_PATHS.each do |path|
        yield path
        expect(response).to have_http_status(:unauthorized), "esperava 401 em #{path}"
        expect(response.headers["WWW-Authenticate"]).to start_with("Basic")
      end
    end

    it "pede credencial a quem não está logado" do
      expect_basic_challenge { |path| get path }
    end

    it "pede credencial ao vendedor" do
      sign_in_as(approved_seller.users.first)

      expect_basic_challenge { |path| get path }
    end

    it "pede credencial ao cliente logado" do
      customer = Customer.create!(name: "Cliente", email: "cliente-docs@example.com", password: "password123")
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect_basic_challenge { |path| get path }
    end

    it "pede credencial ao admin depois que ele sai" do
      sign_in_as(User.create!(email_address: "admin-docs-saida@eloshop.test", password: "password123"))
      sign_out

      expect_basic_challenge { |path| get path }
    end

    it "recusa token inválido ou revogado" do
      revoked = ApiClient.create!(name: "Cliente revogado docs")
      revoked.revoke!

      [ "token-invalido", revoked.token ].each do |token|
        expect_basic_challenge { |path| get path, headers: basic_auth(token) }
      end
    end

    it "abre a documentação para o token ativo, com qualquer usuário" do
      client = ApiClient.create!(name: "Cliente docs")

      DOC_PATHS.each do |path|
        get path, headers: basic_auth(client.token, user: "tanto-faz")
        expect(response).to have_http_status(:ok), "esperava 200 em #{path}"
      end
      expect(client.reload.last_used_at).to be_present
    end
  end

  # O script de inicialização é estático (public/), servido antes do roteador:
  # fica fora da restrição. Não carrega dado da API, só lê a configuração que
  # a página protegida passa em data-*.
  it "serve o script de inicialização da própria aplicação, não o do pacote" do
    get "/api-docs/eloshop-swagger-init.js"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("SwaggerUIBundle(configObject)")
    expect(response.body).to include("container.dataset.config")
  end

  context "com o admin logado" do
    before { sign_in_as(User.create!(email_address: "admin-docs@eloshop.test", password: "password123")) }

    it "serve a página sem script inline e sob a CSP estrita da aplicação" do
      get "/api-docs/index.html"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/<script(?![^>]*\bsrc=)[^>]*>/)
      expect(response.body).not_to include("fonts.googleapis.com")
      expect(response.body).to include('<script src="./eloshop-swagger-init.js"></script>')
      expect(response.body).to include("/api-docs/v1/swagger.yaml")

      script_src = response.headers["Content-Security-Policy"][/script-src ([^;]*)/, 1]
      expect(script_src).not_to include("'unsafe-inline'")
    end

    it "serve a especificação OpenAPI" do
      get "/api-docs/v1/swagger.yaml"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("openapi:")
    end
  end
end
