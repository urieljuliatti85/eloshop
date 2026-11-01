module Api
  module V1
    # Base da API v1: leitura do que a loja já mostra, só para quem tem um
    # token emitido pelo admin (`ApiClient`), enviado como
    # `Authorization: Bearer <token>`. A sessão de `User` não vale aqui —
    # nem a do admin —, para a API ter uma única porta de entrada.
    # Nenhum endpoint aqui expõe dado de cliente ou de operação do vendedor.
    class BaseController < ApplicationController
      allow_unauthenticated_access
      before_action :authenticate_api_client!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end

      private

      def authenticate_api_client!
        api_client = authenticate_with_http_token { |token, _options| ApiClient.authenticate(token) }
        return api_client.track_usage! if api_client

        response.headers["WWW-Authenticate"] = %(Bearer realm="EloShop API")
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end
  end
end
