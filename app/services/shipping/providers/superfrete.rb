require "net/http"
require "json"

module Shipping
  module Providers
    # Cotação de frete na SuperFrete (ADR 005), com o token da conta que o
    # ateliê conectou (Marketplace::SuperfreteOauth). Devolve Shipping::Quote,
    # e qualquer falha vira Providers::Unavailable — o Calculator segue com o
    # frete do ateliê.
    class Superfrete
      class Unavailable < Providers::Unavailable; end

      HOSTS = { production: "api.superfrete.com", sandbox: "sandbox.superfrete.com" }.freeze
      CALCULATE_PATH = "/api/v0/calculator"

      # PAC, SEDEX e Mini Envios — os serviços dos Correios que a
      # documentação lista com código fixo. Jadlog, Loggi e J&T dependem de
      # ponto de coleta perto da origem; ficam de fora até haver demanda.
      SERVICES = "1,2,17".freeze

      # Curtos de propósito: isto roda no checkout, e uma cotação lenta custa
      # mais que o frete do ateliê, que é o fallback.
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 5

      USER_AGENT = Marketplace::SuperfreteOauth::USER_AGENT

      def initialize(seller:)
        @seller = seller
      end

      def quotes(origin_zip_code:, destination_zip_code:, items:)
        response = post(
          CALCULATE_PATH,
          from: { postal_code: origin_zip_code },
          to: { postal_code: destination_zip_code },
          services: SERVICES,
          options: { own_hand: false, receipt: false, insurance_value: insurance_value(items), use_insurance_value: false },
          products: items.map { |item| product_payload(item) }
        )

        raise Unavailable, "resposta inesperada da SuperFrete" unless response.is_a?(Array)

        response.filter_map { |option| build_quote(option) }
      end

      # O que muda o preço sem mudar o carrinho: a conta conectada (cada uma
      # tem o próprio desconto) e o ambiente. Entra na chave do cache do
      # Calculator para que trocar de conta não reaproveite a cotação antiga.
      def cache_scope
        [ @seller.superfrete_account_id, @seller.superfrete_sandbox? ? "sandbox" : "production" ].join(":")
      end

      private

      def product_payload(item)
        {
          quantity: item.fetch(:quantity).to_i,
          height: item.fetch(:height_cm).to_i,
          width: item.fetch(:width_cm).to_i,
          length: item.fetch(:length_cm).to_i,
          weight: (item.fetch(:weight_grams).to_f / 1000).round(3)
        }
      end

      def insurance_value(items)
        (items.sum { |item| item.fetch(:price_cents).to_i * item.fetch(:quantity).to_i } / 100.0).round(2)
      end

      # Serviços indisponíveis para a rota (fora de cobertura, acima do limite
      # da transportadora) vêm no mesmo array, marcados com `has_error` ou
      # `error`: descartados.
      def build_quote(option)
        return nil unless option.is_a?(Hash)
        return nil if option["has_error"] || option["error"].present?

        price = option["price"]
        delivery_time = option["delivery_time"]
        return nil if price.blank? || delivery_time.blank?

        Shipping::Quote.new(
          carrier: option.dig("company", "name").to_s.presence || "SuperFrete",
          service: option["name"].to_s.presence || "Entrega",
          shipping_cents: (BigDecimal(price.to_s) * 100).round.to_i,
          estimated_days: Integer(delivery_time)
        )
      rescue ArgumentError, TypeError
        nil
      end

      def post(path, body)
        token = @seller.superfrete_access_token
        raise Unavailable, "a conta SuperFrete do ateliê não está conectada" if token.blank?

        request = Net::HTTP::Post.new(path)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request["User-Agent"] = USER_AGENT
        request.body = body.to_json

        response = http.request(request)
        report_revoked_token if response.is_a?(Net::HTTPUnauthorized)

        # Sem o corpo da resposta na mensagem: ele pode ecoar o endereço do
        # cliente, e esta exceção vai para o log.
        raise Unavailable, "SuperFrete respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        raise Unavailable, "resposta ilegível da SuperFrete"
      rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
        raise Unavailable, "não foi possível consultar a SuperFrete"
      end

      # O token não expira: um 401 quer dizer que o ateliê revogou a
      # integração do lado da SuperFrete. O checkout segue com o frete dele, e
      # a revogação fica gravada: a conexão deixa de contar (etapa, aprovação
      # e cotação) e o painel pede para reconectar.
      def report_revoked_token
        @seller.mark_superfrete_revoked!
        Rails.event.notify("shipping.provider_unauthorized", provider: "superfrete", seller_id: @seller.id)
      end

      def host
        @seller.superfrete_sandbox? ? HOSTS[:sandbox] : HOSTS[:production]
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
