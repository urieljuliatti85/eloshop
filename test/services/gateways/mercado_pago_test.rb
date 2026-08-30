require "test_helper"

module Gateways
  # HTTP é stubado: estes testes verificam o contrato do adapter (o que ele
  # envia, o que devolve, o que recusa), não a API do Mercado Pago. A
  # verificação contra o sandbox real depende de credenciais e ainda não foi
  # feita — ver docs/payments.md.
  class MercadoPagoTest < ActiveSupport::TestCase
    ACCESS_TOKEN = "TEST-token"
    WEBHOOK_SECRET = "webhook-secret"

    setup do
      @gateway = MercadoPago.new(access_token: ACCESS_TOKEN, webhook_secret: WEBHOOK_SECRET)
      @order = orders(:one)
    end

    test "name identifies the gateway stored on the payment" do
      assert_equal "mercado_pago", @gateway.name
    end

    test "authorize returns the pix code and expiration" do
      stub_request(
        "id" => 12_345,
        "status" => "pending",
        "date_of_expiration" => "2026-08-30T12:00:00.000-03:00",
        "point_of_interaction" => {
          "transaction_data" => {
            "qr_code" => "00020126580014BR.GOV.BCB.PIX",
            "qr_code_base64" => "aGVsbG8="
          }
        }
      ) do
        intent = @gateway.authorize(order: @order)

        assert_equal "12345", intent.external_id
        assert_equal "00020126580014BR.GOV.BCB.PIX", intent.qr_code
        assert_equal "aGVsbG8=", intent.qr_code_base64
        assert intent.expires_at.present?
        assert intent.pix?
      end
    end

    # A chave de idempotência precisa ser estável por pedido: é ela que impede
    # uma requisição repetida (timeout, retry) de virar segunda cobrança.
    test "authorize sends the order idempotency key" do
      captured = stub_request("id" => 1, "point_of_interaction" => {}) do
        @gateway.authorize(order: @order)
      end

      assert_equal @order.idempotency_key, captured["X-Idempotency-Key"]
      body = JSON.parse(captured.body)
      assert_equal "pix", body["payment_method_id"]
      assert_equal @order.id.to_s, body["external_reference"]
    end

    test "authorize fails loudly without an access token" do
      gateway = MercadoPago.new(access_token: nil, webhook_secret: WEBHOOK_SECRET)

      assert_raises(MercadoPago::ConfigurationError) { gateway.authorize(order: @order) }
    end

    test "payment_status translates gateway vocabulary into the domain's" do
      { "approved" => "approved", "authorized" => "approved", "rejected" => "declined",
        "cancelled" => "declined", "in_process" => "pending" }.each do |remoto, esperado|
        stub_request("status" => remoto) do
          assert_equal esperado, @gateway.payment_status(external_id: "1"), "status #{remoto}"
        end
      end
    end

    # Status desconhecido não pode virar "aprovado" por omissão: na dúvida, o
    # pedido continua pendente.
    test "payment_status treats an unknown status as pending" do
      stub_request("status" => "algo_novo_do_gateway") do
        assert_equal "pending", @gateway.payment_status(external_id: "1")
      end
    end

    test "verify_webhook accepts a correctly signed notification" do
      assert @gateway.verify_webhook(signed_request)
    end

    test "verify_webhook rejects a tampered signature" do
      assert_not @gateway.verify_webhook(signed_request(signature: "v1=deadbeef,ts=1"))
    end

    test "verify_webhook rejects a notification without a signature" do
      assert_not @gateway.verify_webhook(signed_request(signature: ""))
    end

    # Sem segredo configurado, aceitar qualquer notificação deixaria qualquer
    # um marcar um pedido como pago.
    test "verify_webhook rejects everything when no secret is configured" do
      gateway = MercadoPago.new(access_token: ACCESS_TOKEN, webhook_secret: nil)

      assert_not gateway.verify_webhook(signed_request)
    end

    # O Mercado Pago notifica o mesmo pagamento a cada mudança de status. Usar
    # só o id do pagamento faria a segunda notificação ser descartada como
    # duplicada por Payments::ProcessWebhook.
    test "webhook_event distinguishes notifications for the same payment" do
      stub_request("status" => "pending") do
        pendente = @gateway.webhook_event(signed_request)
        assert_equal "pending", pendente[:status]

        stub_request("status" => "approved") do
          aprovado = @gateway.webhook_event(signed_request)
          assert_equal "approved", aprovado[:status]
          assert_not_equal pendente[:event_id], aprovado[:event_id]
        end
      end
    end

    private

    def signed_request(signature: nil, data_id: "12345", request_id: "req-1", ts: "1700000000")
      manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts};"
      digest = OpenSSL::HMAC.hexdigest("SHA256", WEBHOOK_SECRET, manifest)

      ActionDispatch::TestRequest.create.tap do |request|
        request.headers["X-Signature"] = signature || "ts=#{ts},v1=#{digest}"
        request.headers["X-Request-Id"] = request_id
        request.params.merge!("data" => { "id" => data_id })
      end
    end

    # Substitui a camada HTTP do adapter: responde sempre com o payload
    # informado e devolve a requisição que o adapter montou, para inspecionar
    # cabeçalhos e corpo depois do bloco.
    def stub_request(payload)
      captured = nil
      fake_http = Object.new

      fake_http.define_singleton_method(:request) do |req|
        captured = req
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.define_singleton_method(:body) { payload.to_json }
        response
      end

      @gateway.instance_variable_set(:@http, fake_http)
      yield
      captured
    ensure
      @gateway.remove_instance_variable(:@http) if @gateway.instance_variable_defined?(:@http)
    end
  end
end
