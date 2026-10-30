# frozen_string_literal: true

require "rails_helper"

# O template padrão do rswag-ui inicializa o Swagger UI com <script> inline,
# que a CSP da aplicação bloqueia: a página abria em branco. O override em
# swagger/index.erb tira todo script inline; estes exemplos impedem que um
# `rails g rswag:ui:custom` ou upgrade da gem traga o original de volta.
RSpec.describe "API docs (Swagger UI)", type: :request do
  DOC_PATHS = [ "/api-docs/index.html", "/api-docs/v1/swagger.yaml" ].freeze

  # A API v1 é pública, mas a documentação não: só o admin da plataforma vê a
  # página e a especificação. Os demais recebem 404 do roteador.
  describe "acesso" do
    it "esconde a documentação de quem não está logado" do
      DOC_PATHS.each do |path|
        get path
        expect(response).to have_http_status(:not_found), "esperava 404 em #{path}"
      end
    end

    it "esconde a documentação do vendedor" do
      sign_in_as(approved_seller.users.first)

      DOC_PATHS.each do |path|
        get path
        expect(response).to have_http_status(:not_found), "esperava 404 em #{path}"
      end
    end

    it "esconde a documentação do cliente logado" do
      customer = Customer.create!(name: "Cliente", email: "cliente-docs@example.com", password: "password123")
      post customer_session_path, params: { email: customer.email, password: "password123" }

      DOC_PATHS.each do |path|
        get path
        expect(response).to have_http_status(:not_found), "esperava 404 em #{path}"
      end
    end

    it "esconde a documentação depois que o admin sai" do
      sign_in_as(User.create!(email_address: "admin-docs-saida@eloshop.test", password: "password123"))
      sign_out

      get "/api-docs/index.html"
      expect(response).to have_http_status(:not_found)
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
