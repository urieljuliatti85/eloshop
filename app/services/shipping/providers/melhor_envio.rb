require "net/http"
require "json"

module Shipping
  module Providers
    # Cotação real de frete no Melhor Envio (ADR 005, Etapa 1).
    #
    # Sem SDK oficial, pelo mesmo motivo do Gateways::MercadoPago: é uma
    # chamada HTTP, e a gem traria dependência desproporcional (CLAUDE.md §3).
    #
    # O token é do vendedor, obtido pela conexão OAuth do painel — não existe
    # conta única da plataforma cotando por todo mundo (ADR 005: a carteira
    # pré-paga é de cada artesão).
    class MelhorEnvio
      class Unavailable < StandardError; end

      PRODUCTION_HOST = "melhorenvio.com.br"
      SANDBOX_HOST = "sandbox.melhorenvio.com.br"
      CALCULATE_PATH = "/api/v2/me/shipment/calculate"

      # Timeouts curtos de propósito: isto roda dentro do checkout, e uma
      # cotação lenta custa mais que uma cotação estimada (ADR 005 — o
      # fallback para a tabela interna existe justamente para isso).
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 5

      # O Melhor Envio pede o User-Agent com nome e contato da aplicação.
      USER_AGENT = "EloShop (contato@eloshop.com.br)".freeze

      def initialize(seller:, access_token_service: Marketplace::MelhorEnvioAccessToken)
        @seller = seller
        @access_token_service = access_token_service
      end

      # Devolve uma lista de Shipping::Quote, uma por serviço disponível.
      # Serviços que o provedor devolve com erro (fora de cobertura, peso
      # acima do limite da transportadora) são descartados: eles vêm no
      # mesmo array dos válidos, marcados com a chave "error".
      def quotes(origin_zip_code:, destination_zip_code:, items:)
        response = post(
          CALCULATE_PATH,
          body: {
            from: { postal_code: origin_zip_code },
            to: { postal_code: destination_zip_code },
            products: items.map { |item| product_payload(item) }
          }
        )

        raise Unavailable, "resposta inesperada do Melhor Envio" unless response.is_a?(Array)

        response.filter_map { |option| build_quote(option) }
      end

      private

      def product_payload(item)
        {
          id: item.fetch(:id).to_s,
          width: item.fetch(:width_cm).to_i,
          height: item.fetch(:height_cm).to_i,
          length: item.fetch(:length_cm).to_i,
          weight: (item.fetch(:weight_grams).to_f / 1000).round(3),
          insurance_value: (item.fetch(:price_cents).to_i / 100.0).round(2),
          quantity: item.fetch(:quantity).to_i
        }
      end

      def build_quote(option)
        return nil unless option.is_a?(Hash)
        return nil if option["error"].present?

        price = option["price"]
        delivery_time = option["delivery_time"]
        return nil if price.blank? || delivery_time.blank?

        Shipping::Quote.new(
          carrier: option.dig("company", "name").to_s.presence || "Melhor Envio",
          service: option["name"].to_s.presence || "Entrega",
          shipping_cents: (BigDecimal(price.to_s) * 100).round.to_i,
          estimated_days: Integer(delivery_time)
        )
      rescue ArgumentError, TypeError
        nil
      end

      def access_token
        @access_token ||= @access_token_service.new(seller: @seller).call
      end

      def host
        @seller.melhor_envio_sandbox? ? SANDBOX_HOST : PRODUCTION_HOST
      end

      def post(path, body:)
        request = Net::HTTP::Post.new(path)
        request["Authorization"] = "Bearer #{access_token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request["User-Agent"] = USER_AGENT
        request.body = body.to_json

        response = http.request(request)

        # Sem o corpo da resposta na mensagem: ele pode ecoar endereço do
        # cliente, e esta exceção vai para o log.
        raise Unavailable, "Melhor Envio respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        raise Unavailable, "resposta ilegível do Melhor Envio"
      rescue Marketplace::MelhorEnvioOauth::ConfigurationError,
        Marketplace::MelhorEnvioOauth::RequestFailed => e
        raise Unavailable, e.message
      rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
        raise Unavailable, "não foi possível consultar o Melhor Envio"
      end

      def http
        @http ||= Net::HTTP.new(host, 443).tap do |client|
          client.use_ssl = true
          client.open_timeout = OPEN_TIMEOUT
          client.read_timeout = READ_TIMEOUT
        end
      end
    end
  end
end
