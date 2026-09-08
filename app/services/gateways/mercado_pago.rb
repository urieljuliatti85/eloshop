require "net/http"
require "json"

module Gateways
  # Adapter do Mercado Pago para PIX (Fase 20, Etapa B) e cartão de crédito
  # (Fase 24).
  #
  # Sem SDK oficial de propósito: são três chamadas HTTP, e a gem traria
  # dependência e superfície de atualização desproporcionais ao uso (CLAUDE.md
  # §3). Net::HTTP resolve.
  #
  # Credenciais vêm de variáveis de ambiente, não das credentials do Rails,
  # para permitir rotação do token sem novo deploy — pagamento é justamente
  # onde girar uma chave comprometida precisa ser rápido.
  class MercadoPago
    class ConfigurationError < StandardError; end
    class RequestFailed < StandardError; end

    API_HOST = "api.mercadopago.com"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # O Mercado Pago tem muitos status; o domínio usa um vocabulário menor.
    # Mapear aqui evita que vocabulário do fornecedor vaze para
    # Payments::ProcessWebhook.
    STATUS_MAP = {
      "approved" => "approved",
      "authorized" => "approved",
      "pending" => "pending",
      "in_process" => "pending",
      "in_mediation" => "pending",
      "rejected" => "declined",
      "cancelled" => "declined",
      "refunded" => "refunded",
      "charged_back" => "declined"
    }.freeze

    def initialize(access_token: nil,
                   webhook_secret: ENV["MERCADO_PAGO_WEBHOOK_SECRET"])
      @access_token_override = access_token
      @webhook_secret = webhook_secret
    end

    def name
      "mercado_pago"
    end

    # Cria uma cobrança PIX ou cartão de crédito.
    #
    # A chave pertence à tentativa de pagamento, não ao checkout. Ela continua
    # estável quando a mesma tentativa é retomada após timeout, mas muda quando
    # um PIX expirado exige uma cobrança nova.
    #
    # PIX sempre nasce "pending" (o QR code é exibido e a confirmação chega
    # depois via webhook). Cartão aprova ou recusa na própria resposta —
    # `token`/`installments` só fazem sentido para cartão; o gateway do
    # Mercado Pago rejeita o payload se forem enviados junto com PIX.
    def authorize(order:, idempotency_key:, application_fee_cents:, payment_method: "pix", card_token: nil, installments: 1)
      if payment_method == "credit_card"
        authorize_credit_card(order: order, idempotency_key: idempotency_key, application_fee_cents: application_fee_cents,
                               card_token: card_token, installments: installments)
      else
        authorize_pix(order: order, idempotency_key: idempotency_key, application_fee_cents: application_fee_cents)
      end
    end

    # A notificação do Mercado Pago não carrega o status de forma confiável —
    # ela avisa "o pagamento X mudou" e espera que a aplicação consulte. Sem
    # isso, bastaria forjar um POST para marcar um pedido como pago.
    def payment_status(external_id:)
      payment_details(external_id: external_id)[:status]
    end

    def refund(payment:, amount_cents:, idempotency_key:)
      access_token = access_token_for(payment.order)
      response = post(
        "/v1/payments/#{payment.external_id}/refunds",
        body: { amount: (amount_cents / 100.0).round(2) },
        headers: { "X-Idempotency-Key" => idempotency_key },
        access_token: access_token
      )

      RefundIntent.new(
        external_id: response["id"].to_s,
        status: refund_status(response["status"])
      )
    end

    # Autenticidade via HMAC-SHA256 sobre um manifesto montado com o id do
    # recurso, o x-request-id e o timestamp do próprio cabeçalho x-signature.
    # Comparação timing-safe.
    def verify_webhook(request)
      return false if @webhook_secret.blank?

      signature = parse_signature(request.headers["X-Signature"])
      timestamp = signature[:ts]
      received = signature[:v1]
      return false if timestamp.blank? || received.blank?

      data_id = request.params.dig("data", "id") || request.params["data.id"]
      manifest = "id:#{data_id};request-id:#{request.headers['X-Request-Id']};ts:#{timestamp};"
      expected = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, manifest)

      ActiveSupport::SecurityUtils.secure_compare(expected, received)
    end

    # Traduz a notificação para o vocabulário que Payments::ProcessWebhook
    # entende. O id do evento combina recurso e status: o Mercado Pago notifica
    # o mesmo pagamento várias vezes conforme ele muda, e usar só o id do
    # pagamento faria a segunda notificação ser descartada como duplicata.
    def webhook_event(request)
      external_id = request.params.dig("data", "id") || request.params["data.id"]
      return nil if external_id.blank?

      details = payment_details(external_id: external_id)

      {
        event_id: "mp-#{external_id}-#{details[:status]}-fee-#{details[:processor_fee_cents]}",
        external_id: external_id.to_s,
        status: details[:status],
        processor_fee_cents: details[:processor_fee_cents]
      }
    end

    private

    def authorize_pix(order:, idempotency_key:, application_fee_cents:)
      access_token = access_token_for(order)

      response = post(
        "/v1/payments",
        body: {
          transaction_amount: (order.total_cents / 100.0).round(2),
          application_fee: (application_fee_cents / 100.0).round(2),
          payment_method_id: "pix",
          description: "Pedido #{order.id} — EloShop",
          external_reference: order.id.to_s,
          payer: { email: payer_email_for(order) }
        },
        headers: { "X-Idempotency-Key" => idempotency_key },
        access_token: access_token
      )

      pix = response.dig("point_of_interaction", "transaction_data") || {}

      Intent.new(
        external_id: response["id"].to_s,
        status: STATUS_MAP.fetch(response["status"].to_s, "pending"),
        qr_code: pix["qr_code"],
        qr_code_base64: pix["qr_code_base64"],
        expires_at: parse_time(response["date_of_expiration"])
      )
    end

    # Token gerado pelo Card Payment Brick no navegador — nunca o número do
    # cartão em si. `installments` chega do mesmo Brick, que já calculou as
    # opções de parcela com a taxa do emissor.
    def authorize_credit_card(order:, idempotency_key:, application_fee_cents:, card_token:, installments:)
      raise ArgumentError, "card_token é obrigatório para cartão de crédito" if card_token.blank?

      access_token = access_token_for(order)

      response = post(
        "/v1/payments",
        body: {
          transaction_amount: (order.total_cents / 100.0).round(2),
          application_fee: (application_fee_cents / 100.0).round(2),
          token: card_token,
          installments: installments,
          description: "Pedido #{order.id} — EloShop",
          external_reference: order.id.to_s,
          payer: { email: payer_email_for(order) }
        },
        headers: { "X-Idempotency-Key" => idempotency_key },
        access_token: access_token
      )

      card = response["card"] || {}

      Intent.new(
        external_id: response["id"].to_s,
        status: STATUS_MAP.fetch(response["status"].to_s, "declined"),
        card_last_four: card["last_four_digits"],
        card_brand: response["payment_method_id"]
      )
    end

    def access_token_for(order)
      token = @access_token_override || seller_access_token(order.seller_order.seller)
      return token if token.present?

      raise ConfigurationError, "a conta Mercado Pago do artesão não está conectada"
    end

    # No sandbox, o Mercado Pago recusa o pagamento (400 "user_allowed_only_
    # in_test") quando o payer.email não é uma conta TESTUSER do tipo
    # Comprador — o e-mail real do cliente EloShop não é aceito ali. Em
    # produção (conta live) o e-mail do cliente segue normalmente.
    def payer_email_for(order)
      seller = order.seller_order.seller
      return order.customer.email unless seller.mercado_pago_test_account?

      ENV.fetch("MERCADO_PAGO_TEST_PAYER_EMAIL", order.customer.email)
    end

    def payment_details(external_id:)
      payment = Payment.find_by(external_id: external_id)
      seller = payment&.order&.seller_order&.seller
      access_token = @access_token_override || (seller_access_token(seller) if seller)
      raise ConfigurationError, "a conta Mercado Pago do artesão não está conectada" if access_token.blank?

      response = get("/v1/payments/#{external_id}", access_token: access_token)
      {
        status: STATUS_MAP.fetch(response["status"].to_s, "pending"),
        processor_fee_cents: processor_fee_cents(response)
      }
    end

    def processor_fee_cents(response)
      amount = Array(response["fee_details"])
        .select { |fee| fee["type"].to_s == "mercadopago_fee" }
        .sum { |fee| BigDecimal(fee["amount"].to_s) }
      (amount * 100).round.to_i
    end

    def refund_status(remote_status)
      case remote_status.to_s
      when "approved" then "approved"
      when "pending", "in_process" then "processing"
      else "failed"
      end
    end

    def seller_access_token(seller)
      Marketplace::MercadoPagoAccessToken.new(seller: seller).call
    rescue Marketplace::MercadoPagoOauth::ConfigurationError => e
      raise ConfigurationError, e.message
    rescue Marketplace::MercadoPagoOauth::RequestFailed => e
      raise RequestFailed, e.message
    end

    def parse_signature(header)
      header.to_s.split(",").each_with_object({}) do |part, acc|
        key, value = part.split("=", 2)
        acc[key.to_s.strip.to_sym] = value.to_s.strip if key && value
      end
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def get(path, access_token:)
      request = Net::HTTP::Get.new(path)
      perform(request, access_token: access_token)
    end

    def post(path, body:, headers: {}, access_token:)
      request = Net::HTTP::Post.new(path)
      headers.each { |key, value| request[key] = value }
      request.body = body.to_json
      perform(request, access_token: access_token)
    end

    def perform(request, access_token:)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        log_error_response(response, request.path)
        # Sem o corpo da resposta na mensagem: ele pode ecoar dados do
        # pagamento, e esta exceção vai para o log. Só o código de erro entra,
        # porque é ele que diz o que houve — "respondeu 500" sozinho custou uma
        # investigação inteira em 2026-09-08.
        code = error_code(response)
        raise RequestFailed, "Mercado Pago respondeu #{response.code} em #{request.path}#{" (#{code})" if code}"
      end

      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      raise RequestFailed, "resposta ilegível do Mercado Pago em #{request.path}"
    end

    # Permanente, e não mais temporário: foi este log que identificou a causa do
    # HTTP 500 em /v1/payments no sandbox (2026-09-08). Sem ele a exceção só
    # dizia "respondeu 500", e a causa real — `user_allowed_only_in_test`, que
    # o Mercado Pago devolve quando o método pedido não está habilitado na conta
    # — ficava invisível. Loga só error/message/cause, nunca o payload completo,
    # que pode ecoar dados do pagamento (§43).
    def log_error_response(response, path)
      body = JSON.parse(response.body.to_s)
      Rails.event.notify(
        "payment.mercado_pago_gateway_http_error",
        path: path,
        http_status: response.code,
        error: body["error"],
        message: body["message"],
        cause: body["cause"]
      )
    rescue StandardError
      nil
    end

    # O identificador do erro do Mercado Pago (ex.: "user_allowed_only_in_test")
    # é seguro para a mensagem da exceção — é um código de causa, não conteúdo
    # do pagamento. O resto do corpo continua de fora.
    def error_code(response)
      body = JSON.parse(response.body.to_s)
      body["error"].presence
    rescue StandardError
      nil
    end

    def http
      @http ||= Net::HTTP.new(API_HOST, 443).tap do |client|
        client.use_ssl = true
        client.open_timeout = OPEN_TIMEOUT
        client.read_timeout = READ_TIMEOUT
      end
    end
  end
end
