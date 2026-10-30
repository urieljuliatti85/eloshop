require "test_helper"

module Shipping
  module Providers
    # HTTP é stubado: estes testes verificam o contrato do adapter (o que ele
    # envia, o que devolve, o que descarta), não a API da SuperFrete. O formato
    # vem da documentação oficial (superfrete.readme.io/reference/cotacao-de-frete).
    class SuperfreteTest < ActiveSupport::TestCase
      setup do
        @seller = sellers(:approved)
        @seller.connect_superfrete!(access_token: "seller-token", account: Marketplace::SuperfreteOauth::Account.new(id: "sf-1", email: "atelie@example.com"))
        @provider = Superfrete.new(seller: @seller)
      end

      test "sends origin, destination, services and the products with converted units" do
        captured = stub_request([]) { quote }

        assert_equal Superfrete::CALCULATE_PATH, captured.path
        body = JSON.parse(captured.body)
        assert_equal "01001000", body.dig("from", "postal_code")
        assert_equal "20000000", body.dig("to", "postal_code")
        assert_equal "1,2,17", body["services"]
        # Seguro em reais, pelo valor total dos itens.
        assert_in_delta 179.8, body.dig("options", "insurance_value"), 0.01

        product = body["products"].sole
        assert_equal 2, product["quantity"]
        assert_equal 10, product["height"]
        assert_equal 20, product["width"]
        assert_equal 30, product["length"]
        # A API pede quilos; o catálogo guarda gramas.
        assert_in_delta 1.2, product["weight"], 0.001
      end

      test "authenticates with the seller token and identifies the application" do
        captured = stub_request([]) { quote }

        assert_equal "Bearer seller-token", captured["Authorization"]
        assert_equal Superfrete::USER_AGENT, captured["User-Agent"]
        assert_equal "application/json", captured["Content-Type"]
      end

      test "turns each available service into a quote and drops the unavailable ones" do
        quotes = quotes_for([
          { "id" => 1, "name" => "PAC", "price" => 20.68, "delivery_time" => 8, "company" => { "name" => "Correios" } },
          { "id" => 2, "name" => "SEDEX", "price" => "30.30", "delivery_time" => 3, "company" => { "name" => "Correios" } },
          { "id" => 17, "name" => "Mini Envios", "has_error" => true, "error" => "Peso acima do limite" },
          { "id" => 3, "name" => "Sem preço", "delivery_time" => 5 }
        ])

        assert_equal [ [ "Correios", "PAC", 2068, 8 ], [ "Correios", "SEDEX", 3030, 3 ] ],
          quotes.map { |q| [ q.carrier, q.service, q.shipping_cents, q.estimated_days ] }
      end

      test "raises Unavailable on an unexpected payload" do
        assert_raises(Superfrete::Unavailable) { quotes_for({ "message" => "erro" }) }
      end

      test "a 401 means the token was revoked: reports it and raises Unavailable without leaking the body" do
        fake_http = Object.new
        fake_http.define_singleton_method(:request) do |_request|
          Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap do |response|
            response.define_singleton_method(:body) { '{"address":"Rua do cliente 123"}' }
          end
        end
        @provider.instance_variable_set(:@http, fake_http)

        capture_rails_events("shipping.provider_unauthorized") do |events|
          error = assert_raises(Superfrete::Unavailable) { quote }
          assert_not_includes error.message, "Rua do cliente"
          assert_equal({ provider: "superfrete", seller_id: @seller.id }, events.sole[:payload])
        end
      end

      test "raises Unavailable on a network failure" do
        fake_http = Object.new
        fake_http.define_singleton_method(:request) { |_request| raise Net::OpenTimeout, "internal host" }
        @provider.instance_variable_set(:@http, fake_http)

        error = assert_raises(Superfrete::Unavailable) { quote }
        assert_not_includes error.message, "internal host"
      end

      test "raises Unavailable when the seller is not connected, without calling the API" do
        @seller.disconnect_superfrete!
        fake_http = Object.new
        fake_http.define_singleton_method(:request) { |_request| raise "não deveria chamar" }
        @provider.instance_variable_set(:@http, fake_http)

        assert_raises(Superfrete::Unavailable) { quote }
      end

      test "uses the sandbox host for a sandbox connection" do
        assert_equal "api.superfrete.com", @provider.send(:host)

        @seller.update!(superfrete_sandbox: true)
        assert_equal "sandbox.superfrete.com", Superfrete.new(seller: @seller).send(:host)
      end

      private

      def quote
        @provider.quotes(origin_zip_code: "01001000", destination_zip_code: "20000000", items: items)
      end

      def items
        [ { id: 1, width_cm: 20, height_cm: 10, length_cm: 30, weight_grams: 1200, price_cents: 8990, quantity: 2 } ]
      end

      # Responde `payload` e devolve a requisição enviada.
      def stub_request(payload)
        captured = nil
        respond_with(payload) { |request| captured = request }
        yield
        captured
      end

      # Responde `payload` e devolve as cotações montadas a partir dele.
      def quotes_for(payload)
        respond_with(payload)
        quote
      end

      def respond_with(payload, &on_request)
        fake_http = Object.new
        fake_http.define_singleton_method(:request) do |request|
          on_request&.call(request)
          Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
            response.define_singleton_method(:body) { payload.to_json }
          end
        end
        @provider.instance_variable_set(:@http, fake_http)
      end
    end
  end
end
