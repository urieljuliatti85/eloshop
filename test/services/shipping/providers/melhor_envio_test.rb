require "test_helper"

module Shipping
  module Providers
    # HTTP é stubado: estes testes verificam o contrato do adapter (o que ele
    # envia, o que devolve, o que descarta), não a API do Melhor Envio. A
    # verificação contra o sandbox real depende de credenciais e ainda não foi
    # feita — mesma situação do Gateways::MercadoPago.
    class MelhorEnvioTest < ActiveSupport::TestCase
      setup do
        @seller = sellers(:approved)
        @provider = MelhorEnvio.new(seller: @seller, access_token_service: stub_token_service("seller-token"))
      end

      test "sends origin, destination and the products with converted units" do
        captured = stub_request([]) { quote }

        body = JSON.parse(captured.body)
        assert_equal "01001000", body.dig("from", "postal_code")
        assert_equal "20000000", body.dig("to", "postal_code")

        product = body["products"].sole
        assert_equal 20, product["width"]
        assert_equal 10, product["height"]
        assert_equal 30, product["length"]
        # A API pede quilos; o catálogo guarda gramas.
        assert_in_delta 1.2, product["weight"], 0.001
        # E reais, não centavos.
        assert_in_delta 89.9, product["insurance_value"], 0.01
        assert_equal 2, product["quantity"]
      end

      test "authenticates with the seller token and identifies the application" do
        captured = stub_request([]) { quote }

        assert_equal "Bearer seller-token", captured["Authorization"]
        assert_equal MelhorEnvio::USER_AGENT, captured["User-Agent"]
        assert_equal "application/json", captured["Content-Type"]
      end

      test "maps the response into domain quotes" do
        stub_request([
          { "id" => 1, "name" => "PAC", "price" => "23.50", "delivery_time" => 8,
            "company" => { "id" => 1, "name" => "Correios" } },
          { "id" => 2, "name" => "SEDEX", "price" => "45.00", "delivery_time" => 2,
            "company" => { "id" => 1, "name" => "Correios" } }
        ]) do
          quotes = quote

          assert_equal 2, quotes.size
          assert_equal "Correios", quotes.first.carrier
          assert_equal "PAC", quotes.first.service
          assert_equal 2350, quotes.first.shipping_cents
          assert_equal 8, quotes.first.estimated_days
        end
      end

      # O Melhor Envio devolve serviços indisponíveis no mesmo array dos
      # válidos, marcados com "error" — oferecê-los quebraria a compra.
      test "discards options the provider returned with an error" do
        stub_request([
          { "id" => 1, "name" => "PAC", "price" => "23.50", "delivery_time" => 8, "company" => { "name" => "Correios" } },
          { "id" => 3, "name" => "Jadlog", "error" => "Serviço indisponível para o trecho" }
        ]) do
          assert_equal [ "PAC" ], quote.map(&:service)
        end
      end

      test "discards options without price or delivery time" do
        stub_request([
          { "id" => 1, "name" => "Sem preço", "delivery_time" => 8, "company" => { "name" => "Correios" } },
          { "id" => 2, "name" => "Sem prazo", "price" => "10.00", "company" => { "name" => "Correios" } }
        ]) do
          assert_empty quote
        end
      end

      test "raises Unavailable on an HTTP error without leaking the body" do
        fake_http = Object.new
        fake_http.define_singleton_method(:request) do |_request|
          Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap do |response|
            response.define_singleton_method(:body) { '{"address":"Rua do cliente 123"}' }
          end
        end
        @provider.instance_variable_set(:@http, fake_http)

        error = assert_raises(MelhorEnvio::Unavailable) { quote }
        assert_not_includes error.message, "Rua do cliente"
      end

      test "raises Unavailable on a network failure" do
        fake_http = Object.new
        fake_http.define_singleton_method(:request) { |_request| raise Net::OpenTimeout, "internal host" }
        @provider.instance_variable_set(:@http, fake_http)

        error = assert_raises(MelhorEnvio::Unavailable) { quote }
        assert_not_includes error.message, "internal host"
      end

      test "raises Unavailable when the seller connection is missing" do
        provider = MelhorEnvio.new(seller: @seller, access_token_service: failing_token_service)

        assert_raises(MelhorEnvio::Unavailable) do
          provider.quotes(origin_zip_code: "01001000", destination_zip_code: "20000000", items: items)
        end
      end

      test "uses the sandbox host for a sandbox connection" do
        @seller.update!(melhor_envio_sandbox: true)

        assert_equal MelhorEnvio::SANDBOX_HOST, @provider.send(:host)
      end

      private

      def quote
        @provider.quotes(origin_zip_code: "01001000", destination_zip_code: "20000000", items: items)
      end

      def items
        [ { id: 1, width_cm: 20, height_cm: 10, length_cm: 30, weight_grams: 1200, price_cents: 8990, quantity: 2 } ]
      end

      def stub_token_service(token)
        Class.new do
          define_method(:initialize) { |seller:| }
          define_method(:call) { token }
        end
      end

      def failing_token_service
        Class.new do
          define_method(:initialize) { |seller:| }
          define_method(:call) do
            raise Marketplace::MelhorEnvioOauth::ConfigurationError, "a conta Melhor Envio do artesão não está conectada"
          end
        end
      end

      def stub_request(payload)
        captured = nil
        fake_http = Object.new
        fake_http.define_singleton_method(:request) do |request|
          captured = request
          Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
            response.define_singleton_method(:body) { payload.to_json }
          end
        end
        @provider.instance_variable_set(:@http, fake_http)

        yield
        captured
      end
    end
  end
end
