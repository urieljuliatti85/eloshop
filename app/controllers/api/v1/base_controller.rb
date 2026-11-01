module Api
  module V1
    # Base da API v1: leitura do que a loja já mostra, só para quem tem um
    # token emitido pelo admin (`ApiClient`), enviado como
    # `Authorization: Bearer <token>`. A sessão de `User` não vale aqui —
    # nem a do admin —, para a API ter uma única porta de entrada.
    # Nenhum endpoint aqui expõe dado de cliente ou de operação do vendedor.
    #
    # Todo erro responde `{ "error": "<código>" }`, com campos extras só quando
    # ajudam o cliente a corrigir a chamada (`parameter` no 400).
    class BaseController < ApplicationController
      RATE_LIMIT = 120
      RATE_LIMIT_WINDOW = 1.minute

      allow_unauthenticated_access
      before_action :authenticate_api_client!
      # Depois da autenticação, para contar por cliente e não por IP: um app
      # próprio atrás de um único IP não pode esgotar a cota de um parceiro.
      # Sem token não há o que contar — o 401 já encerrou a requisição, e
      # adivinhar um token aleatório de 32 caracteres base58 não é viável.
      # `scope` fixo porque o padrão é o controller_path: sem ele a cota seria
      # por recurso, e não uma só por cliente para a API inteira.
      rate_limit to: RATE_LIMIT, within: RATE_LIMIT_WINDOW, scope: "api/v1",
        by: -> { @api_client.id }, with: -> { render_rate_limited }

      rescue_from ActiveRecord::RecordNotFound do
        render_error "not_found", status: :not_found
      end

      private

      def authenticate_api_client!
        @api_client = authenticate_with_http_token { |token, _options| ApiClient.authenticate(token) }
        return identify_api_client if @api_client

        response.headers["WWW-Authenticate"] = %(Bearer realm="EloShop API")
        render_error "unauthorized", status: :unauthorized
      end

      # O id, nunca o nome nem o token: chega ao log estruturado (Railway)
      # pela linha `action_controller.request_completed` e ao Sentry como tag.
      def identify_api_client
        @api_client.track_usage!
        Rails.event.set_context(api_client_id: @api_client.id)
        Sentry.set_tags(api_client_id: @api_client.id)
      end

      def render_rate_limited
        response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
        render_error "rate_limited", status: :too_many_requests
      end

      def render_invalid_parameter(name)
        render_error "invalid_parameter", status: :bad_request, parameter: name
      end

      def render_error(code, status:, **details)
        render json: { error: code, **details }, status: status
      end
    end
  end
end
