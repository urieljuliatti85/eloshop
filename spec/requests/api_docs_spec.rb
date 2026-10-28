# frozen_string_literal: true

require "rails_helper"

# O template padrão do rswag-ui inicializa o Swagger UI com <script> inline,
# que a CSP da aplicação bloqueia: a página abria em branco. O override em
# swagger/index.erb tira todo script inline; estes exemplos impedem que um
# `rails g rswag:ui:custom` ou upgrade da gem traga o original de volta.
RSpec.describe "API docs (Swagger UI)", type: :request do
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

  it "serve o script de inicialização da própria aplicação, não o do pacote" do
    get "/api-docs/eloshop-swagger-init.js"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("SwaggerUIBundle(configObject)")
    expect(response.body).to include("container.dataset.config")
  end

  it "serve a especificação OpenAPI" do
    get "/api-docs/v1/swagger.yaml"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("openapi:")
  end
end
