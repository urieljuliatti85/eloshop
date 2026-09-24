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
        intent = @gateway.authorize(order: @order, idempotency_key: "attempt-1", application_fee_cents: 1_349)

        assert_equal "12345", intent.external_id
        assert_equal "00020126580014BR.GOV.BCB.PIX", intent.qr_code
        assert_equal "aGVsbG8=", intent.qr_code_base64
        assert intent.expires_at.present?
        assert intent.pix?
      end
    end

    # A chave é estável dentro da tentativa, mas uma tentativa nova recebe
    # outra chave para não recuperar um PIX anterior já expirado.
    test "authorize sends the payment attempt idempotency key" do
      captured = stub_request("id" => 1, "point_of_interaction" => {}) do
        @gateway.authorize(order: @order, idempotency_key: "attempt-2", application_fee_cents: 1_349)
      end

      assert_equal "attempt-2", captured["X-Idempotency-Key"]
      body = JSON.parse(captured.body)
      assert_equal "pix", body["payment_method_id"]
      assert_equal @order.id.to_s, body["external_reference"]
      assert_equal 13.49, body["application_fee"]
    end

    test "authorize sends the card token and installments, not pix fields" do
      captured = stub_request(
        "id" => 55, "status" => "approved",
        "payment_method_id" => "visa", "card" => { "last_four_digits" => "1111" }
      ) do
        @gateway.authorize(
          order: @order, idempotency_key: "attempt-card", application_fee_cents: 1_349,
          payment_method: "credit_card", card_token: "card-token-xyz", installments: 3
        )
      end

      body = JSON.parse(captured.body)
      assert_equal "card-token-xyz", body["token"]
      assert_equal 3, body["installments"]
      assert_nil body["payment_method_id"]
    end

    test "authorize returns approved status and card details for an approved card payment" do
      stub_request(
        "id" => 55, "status" => "approved",
        "payment_method_id" => "visa", "card" => { "last_four_digits" => "1111" }
      ) do
        intent = @gateway.authorize(
          order: @order, idempotency_key: "attempt-card-ok", application_fee_cents: 1_349,
          payment_method: "credit_card", card_token: "card-token-xyz", installments: 1
        )

        assert_equal "55", intent.external_id
        assert_equal "approved", intent.status
        assert_equal "1111", intent.card_last_four
        assert_equal "visa", intent.card_brand
        assert_not intent.pix?
      end
    end

    test "authorize returns declined status for a rejected card payment" do
      stub_request("id" => 56, "status" => "rejected") do
        intent = @gateway.authorize(
          order: @order, idempotency_key: "attempt-card-declined", application_fee_cents: 1_349,
          payment_method: "credit_card", card_token: "card-token-xyz", installments: 1
        )

        assert_equal "declined", intent.status
      end
    end

    test "authorize raises without a card token for credit card" do
      assert_raises(ArgumentError) do
        @gateway.authorize(
          order: @order, idempotency_key: "attempt-card-missing-token", application_fee_cents: 1_349,
          payment_method: "credit_card", card_token: nil, installments: 1
        )
      end
    end

    test "authorize fails loudly without an access token" do
      gateway = MercadoPago.new(access_token: nil, webhook_secret: WEBHOOK_SECRET)

      assert_raises(MercadoPago::ConfigurationError) do
        gateway.authorize(order: @order, idempotency_key: "attempt-3", application_fee_cents: 1_349)
      end
    end

    test "authorize sends the customer's real email when the seller account is live" do
      @order.seller_order.seller.update!(mercado_pago_test_account: false)

      captured = stub_request("id" => 1, "point_of_interaction" => {}) do
        @gateway.authorize(order: @order, idempotency_key: "attempt-live", application_fee_cents: 1_349)
      end

      body = JSON.parse(captured.body)
      assert_equal @order.customer.email, body.dig("payer", "email")
    end

    # No sandbox, o Mercado Pago recusa o pagamento (400
    # "user_allowed_only_in_test") quando o payer.email não é uma conta
    # TESTUSER do tipo Comprador — usar o e-mail real do cliente derruba a
    # cobrança antes mesmo de gerar o PIX.
    test "authorize sends the sandbox test payer email when the seller account is a TESTUSER" do
      @order.seller_order.seller.update!(mercado_pago_test_account: true)

      captured = with_env("MERCADO_PAGO_TEST_PAYER_EMAIL" => "test_payer@testuser.com") do
        stub_request("id" => 1, "point_of_interaction" => {}) do
          @gateway.authorize(order: @order, idempotency_key: "attempt-sandbox", application_fee_cents: 1_349)
        end
      end

      body = JSON.parse(captured.body)
      assert_equal "test_payer@testuser.com", body.dig("payer", "email")
    end

    test "authorize falls back to the customer's email when sandbox but no test payer is configured" do
      @order.seller_order.seller.update!(mercado_pago_test_account: true)

      captured = with_env("MERCADO_PAGO_TEST_PAYER_EMAIL" => nil) do
        stub_request("id" => 1, "point_of_interaction" => {}) do
          @gateway.authorize(order: @order, idempotency_key: "attempt-sandbox-fallback", application_fee_cents: 1_349)
        end
      end

      body = JSON.parse(captured.body)
      assert_equal @order.customer.email, body.dig("payer", "email")
    end

    test "payment_status translates gateway vocabulary into the domain's" do
      { "approved" => "approved", "authorized" => "approved", "rejected" => "declined",
        "cancelled" => "declined", "in_process" => "pending", "refunded" => "refunded" }.each do |remoto, esperado|
        stub_request("status" => remoto) do
          assert_equal esperado, @gateway.payment_status(external_id: "1"), "status #{remoto}"
        end
      end
    end

    test "webhook records the Mercado Pago processor fee separately" do
      stub_request("status" => "approved", "fee_details" => [ { "type" => "mercadopago_fee", "amount" => 4.37 } ]) do
        event = @gateway.webhook_event(signed_request)

        assert_equal 437, event[:processor_fee_cents]
      end
    end

    test "reconciliation details include processor fee and money release date" do
      stub_request(
        "status" => "approved",
        "money_release_date" => "2026-09-25T12:30:00.000-03:00",
        "fee_details" => [ { "type" => "mercadopago_fee", "amount" => 3.59 } ]
      ) do
        details = @gateway.reconciliation_details(external_id: "1")

        assert_equal 359, details[:processor_fee_cents]
        assert_equal Time.zone.parse("2026-09-25T12:30:00.000-03:00"), details[:money_release_date]
      end
    end

    test "refund sends amount and idempotency key" do
      payment = payments(:one)
      captured = stub_request("id" => 99, "status" => "approved") do
        intent = @gateway.refund(payment: payment, amount_cents: 500, idempotency_key: "refund-1")
        assert_equal "99", intent.external_id
        assert_equal "approved", intent.status
      end

      assert_equal "refund-1", captured["X-Idempotency-Key"]
      assert_equal 5.0, JSON.parse(captured.body)["amount"]
    end

    test "refund maps a rejected response to failed" do
      stub_request("id" => 100, "status" => "rejected") do
        intent = @gateway.refund(payment: payments(:one), amount_cents: 500, idempotency_key: "refund-rejected")

        assert_equal "failed", intent.status
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

    # O log de erro existe desde 2026-09-08 justamente porque "respondeu 500"
    # sozinho não diz nada. Só o código de causa entra na exceção; o corpo,
    # que pode ecoar dados do pagamento, fica de fora (§43).
    test "logs the error code when the gateway refuses with JSON" do
      capture_rails_events("payment.mercado_pago_gateway_http_error") do |events|
        stub_error_response(
          code: "400",
          body: { "error" => "user_allowed_only_in_test", "message" => "conta de teste", "cause" => [] }.to_json,
          content_type: "application/json"
        ) do
          erro = assert_raises(MercadoPago::RequestFailed) { @gateway.payment_status(external_id: "1") }
          assert_includes erro.message, "user_allowed_only_in_test"
          assert_not_includes erro.message, "conta de teste"
        end

        payload = events.last[:payload]
        assert_equal "400", payload[:http_status]
        assert_equal "user_allowed_only_in_test", payload[:error]
        assert_nil payload[:body_excerpt]
      end
    end

    # Pedido #48 (2026-09-24): um 500 de /v1/payments chegou com
    # error/message/cause vazios — o Mercado Pago nem sempre usa essas
    # chaves. Sem um excerto do corpo, essa resposta ficava tão opaca quanto
    # um corpo não-JSON.
    test "logs a body excerpt when the JSON error body has no error/message/cause" do
      capture_rails_events("payment.mercado_pago_gateway_http_error") do |events|
        stub_error_response(
          code: "500",
          body: { "status" => 500, "internal_error" => true }.to_json,
          content_type: "application/json"
        ) do
          assert_raises(MercadoPago::RequestFailed) { @gateway.payment_status(external_id: "1") }
        end

        payload = events.last[:payload]
        assert_equal "500", payload[:http_status]
        assert_nil payload[:error]
        assert_includes payload[:body_excerpt], "internal_error"
      end
    end

    # Mesma lacuna que o Melhor Envio tinha até o PR #84: corpo não-JSON caía
    # num `rescue` que devolvia nil, e nenhum evento era emitido. Um 500 opaco
    # de /v1/payments não distingue "o Mercado Pago recusou" de "a requisição
    # nem chegou ao Mercado Pago" — o trecho do corpo identifica a camada.
    test "records the responding layer when the error body is not JSON" do
      capture_rails_events("payment.mercado_pago_gateway_http_error") do |events|
        stub_error_response(
          code: "403",
          body: "<html>\n  <body>\n    <h1>Acesso bloqueado (E-WAF-0003)</h1>\n  </body>\n</html>",
          content_type: "text/html",
          server: "awselb/2.0"
        ) do
          assert_raises(MercadoPago::RequestFailed) { @gateway.payment_status(external_id: "1") }
        end

        payload = events.last[:payload]
        assert_equal "403", payload[:http_status]
        assert_equal "corpo não-JSON", payload[:error]
        assert_equal "text/html", payload[:content_type]
        assert_equal "awselb/2.0", payload[:server]
        # Sem marcação e sem quebras de linha, só o que identifica a camada.
        assert_equal "Acesso bloqueado (E-WAF-0003)", payload[:body_excerpt]
      end
    end

    # CodeQL (rb/polynomial-redos, PR #84): limpar marcação com regex sobre
    # corpo de terceiro é polinomial numa entrada com muitos `<` sem
    # fechamento. Determinístico em vez de cronometrado, pela mesma razão
    # registrada no teste equivalente do Melhor Envio: um corpo hostil de
    # 200 KB que sanitiza para vazio prova que a varredura não engasgou, e
    # medir tempo daria um teste frágil em CI lento.
    test "sanitizes a hostile error body without backtracking" do
      capture_rails_events("payment.mercado_pago_gateway_http_error") do |events|
        stub_error_response(code: "403", body: "<" * 200_000, content_type: "text/html") do
          assert_raises(MercadoPago::RequestFailed) { @gateway.payment_status(external_id: "1") }
        end

        payload = events.last[:payload]
        assert_equal "", payload[:body_excerpt]
        assert_operator payload[:body_excerpt].length, :<=, MercadoPago::BODY_EXCERPT_LIMIT
      end
    end

    private

    # Responde com um erro HTTP em vez do payload de sucesso do stub_request,
    # para exercitar o caminho de log da falha.
    def stub_error_response(code:, body:, content_type: nil, server: nil)
      fake_http = Object.new

      fake_http.define_singleton_method(:request) do |_req|
        Net::HTTPResponse.send(:response_class, code).new("1.1", code, "Error").tap do |response|
          response["content-type"] = content_type if content_type
          response["server"] = server if server
          response.define_singleton_method(:body) { body }
        end
      end

      @gateway.instance_variable_set(:@http, fake_http)
      yield
    ensure
      @gateway.remove_instance_variable(:@http) if @gateway.instance_variable_defined?(:@http)
    end

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
    def with_env(vars)
      originals = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      yield
    ensure
      originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

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
