# A API v1 exige um token de `ApiClient` (ver Api::V1::BaseController).
module ApiAuthenticationHelpers
  def api_token
    @api_token ||= ApiClient.create!(name: "Cliente spec #{SecureRandom.hex(4)}").token
  end

  def api_headers(headers = {})
    { "Authorization" => "Bearer #{api_token}" }.merge(headers)
  end

  # DSL do rswag, dentro de um bloco de operação: documenta e testa o 401 que
  # toda rota da API devolve sem token válido. `path_params` preenche os
  # parâmetros de path que a operação declara, só para a URL existir.
  module Documentation
    def documents_api_token_requirement(**path_params)
      response "401", "token ausente, inválido ou revogado" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        path_params.each { |name, value| let(name) { value } }
        let(:Authorization) { "Bearer token-invalido" }

        run_test! do |response|
          expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
          expect(JSON.parse(response.body)).to eq("error" => "unauthorized")
        end
      end
    end

    # Documenta e testa o 429: esgota a cota do token em outro endpoint antes
    # da chamada, o que prova também que a cota é uma só para a API inteira.
    def documents_rate_limit(**path_params)
      response "429", "cota de requisições do token esgotada" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]
        header "Retry-After", schema: { type: :string }, description: "Segundos até a cota ser renovada"

        path_params.each { |name, value| let(name) { value } }
        before do
          Api::V1::BaseController::RATE_LIMIT.times { get "/api/v1/categories", headers: api_headers }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)).to eq("error" => "rate_limited")
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include ApiAuthenticationHelpers
  config.extend ApiAuthenticationHelpers::Documentation, type: :request
end
