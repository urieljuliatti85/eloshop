module Api
  module V1
    # Base da API pública v1: leitura anônima do que a loja já mostra.
    # Nenhum endpoint aqui expõe dado de cliente ou de operação do vendedor.
    class BaseController < ApplicationController
      allow_unauthenticated_access

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end
    end
  end
end
