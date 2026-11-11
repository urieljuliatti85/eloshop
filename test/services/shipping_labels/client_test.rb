require "test_helper"

module ShippingLabels
  class ClientTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper

    setup do
      prepare_label_scenario
    end

    test "quote keeps the service code and the package SuperFrete adjusted" do
      client = client_responding(200, [
        { "id" => 1, "name" => "PAC", "price" => 23.51, "delivery_time" => 2, "has_error" => false, "company" => { "name" => "Correios" },
          "packages" => [ { "dimensions" => { "height" => "10", "width" => "16", "length" => "24" }, "weight" => "0.5" } ] },
        { "id" => 17, "name" => "Mini Envios", "has_error" => true },
        { "id" => 3, "name" => "Jadlog", "price" => 10, "delivery_time" => 5, "has_error" => false, "packages" => [] }
      ])

      options = client.quote(origin_zip_code: "01001000", destination_zip_code: "20040020", height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500)

      assert_equal [ 1 ], options.map(&:service_code)
      option = options.first
      assert_equal [ 2351, 16, 24, 500 ], [ option.price_cents, option.width_cm, option.length_cm, option.weight_grams ]
    end

    test "order lookup returns only the label fields, never the account's personal data" do
      client = client_responding(200, {
        "id" => "sf-order-1", "status" => "released", "tracking" => "AA123456789BR", "price" => 23.51, "service_id" => 1,
        "print" => { "url" => "https://sandbox.superfrete.com/etiqueta.pdf" },
        "service_calculated" => { "data" => { "user_config" => { "cpf" => "10555718760", "birthdate" => "11/10/1985" } } }
      })

      info = client.order_info("sf-order-1")

      assert info.paid?
      assert_equal "AA123456789BR", info.tracking
      assert_not_includes info.to_h.to_s, "10555718760"
      assert_not_includes info.to_h.to_s, "11/10/1985"
    end

    test "a 409 is a refusal carrying SuperFrete's own message" do
      client = client_responding(409, { "message" => "Sem saldo na carteira! Utilize o app para recarregar a carteira." })

      error = assert_raises(Client::Rejected) { client.checkout("sf-order-1") }
      assert_equal "Sem saldo na carteira! Utilize o app para recarregar a carteira.", error.message
    end

    test "a 400 with field errors shows the field messages, without the generic headline" do
      client = client_responding(400, { "message" => "Ocorreu um ou mais erros.", "errors" => { "to.document" => [ "Campo CPF/CNPJ do destinatário é obrigatório." ] } })

      error = assert_raises(Client::Rejected) { client.create_cart({}) }
      assert_equal "Campo CPF/CNPJ do destinatário é obrigatório.", error.message
    end

    test "creating the webhook returns its id and the secret that signs the notifications" do
      sent = nil
      client = client_responding(201, { "id" => "wh-1", "secret_token" => "f" * 64, "is_active" => true }) { |request| sent = request }

      result = client.create_webhook(name: "EloShop", url: "https://eloshop.test/webhooks/superfrete/k", events: [ "order.posted" ])

      assert_equal({ id: "wh-1", secret: "f" * 64 }, result)
      assert_equal "/api/v0/webhook", sent.path
      assert_equal [ "order.posted" ], JSON.parse(sent.body)["events"]
    end

    test "a webhook created without the secret is uncertain" do
      client = client_responding(201, { "id" => "wh-1" })

      assert_raises(Client::Ambiguous) { client.create_webhook(name: "EloShop", url: "https://x", events: []) }
    end

    test "deleting the webhook sends a DELETE" do
      sent = nil
      client = client_responding(204, nil) { |request| sent = request }

      assert client.delete_webhook("wh-1")
      assert_equal "DELETE", sent.method
      assert_equal "/api/v0/webhook/wh-1", sent.path
    end

    test "a 500 is uncertain, not a refusal: it does not prove nothing was charged" do
      client = client_responding(500, { "message" => "Não foi possível finalizar o pagamento" })

      assert_raises(Client::Ambiguous) { client.checkout("sf-order-1") }
    end

    test "a checkout answer without the paid order is uncertain" do
      client = client_responding(200, { "success" => true, "purchase" => { "status" => "pending", "orders" => [] } })

      assert_raises(Client::Ambiguous) { client.checkout("sf-order-1") }
    end

    test "a successful checkout returns the tracking code" do
      client = client_responding(200, { "success" => true, "purchase" => { "status" => "paid",
        "orders" => [ { "id" => "sf-order-1", "price" => 23.51, "tracking" => "AA123456789BR" } ] } })

      assert_equal({ tracking: "AA123456789BR", price_cents: 2351 }, client.checkout("sf-order-1"))
    end

    test "a timeout is uncertain" do
      http = Object.new
      http.define_singleton_method(:request) { |_request| raise Net::ReadTimeout }

      assert_raises(Client::Ambiguous) { Client.new(seller: @seller, http: http).checkout("sf-order-1") }
    end

    test "a 401 marks the connection as revoked" do
      client = client_responding(401, {})

      assert_raises(Client::Unauthorized) { client.create_cart({}) }
      assert @seller.reload.superfrete_revoked_at.present?
    end

    test "sends the platform name with the order" do
      sent = nil
      client = client_responding(200, { "id" => "sf-order-1", "price" => 23.51, "status" => "pending" }) { |request| sent = JSON.parse(request.body) }

      assert_equal({ id: "sf-order-1", price_cents: 2351 }, client.create_cart({ service: 1 }))
      assert_equal "EloShop", sent["platform"]
    end

    private

    def client_responding(code, payload, &on_request)
      klass = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s)
      http = Object.new
      http.define_singleton_method(:request) do |request|
        on_request&.call(request)
        klass.new("1.1", code.to_s, "").tap { |response| response.define_singleton_method(:body) { payload.to_json } }
      end
      Client.new(seller: @seller, http: http)
    end
  end
end
