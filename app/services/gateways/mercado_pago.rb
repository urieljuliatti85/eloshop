require "net/http"
require "json"

module Gateways
  # Adapter do Mercado Pago para PIX (Fase 20, Etapa B).
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

    # O Mercado Pago tem muitos status; o domínio só conhece três desfechos.
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
      "refunded" => "declined",
      "charged_back" => "declined"
    }.freeze

    def initialize(access_token: ENV["MERCADO_PAGO_ACCESS_TOKEN"],
                   webhook_secret: ENV["MERCADO_PAGO_WEBHOOK_SECRET"])
      @access_token = access_token
      @webhook_secret = webhook_secret
    end

    def name
      "mercado_pago"
    end

    # Cria uma cobrança PIX e devolve o QR code para exibir ao cliente.
    #
    # A chave de idempotência é o idempotency_key do próprio pedido: se a
    # requisição for repetida (timeout, retry), o Mercado Pago devolve a
    # cobrança já criada em vez de cobrar de novo.
    def authorize(order:)
      require_access_token!

      response = post(
        "/v1/payments",
        body: {
          transaction_amount: (order.total_cents / 100.0).round(2),
          payment_method_id: "pix",
          description: "Pedido #{order.id} — EloShop",
          external_reference: order.id.to_s,
          payer: { email: order.customer.email }
        },
        headers: { "X-Idempotency-Key" => order.idempotency_key }
      )

      pix = response.dig("point_of_interaction", "transaction_data") || {}

      Intent.new(
        external_id: response["id"].to_s,
        qr_code: pix["qr_code"],
        qr_code_base64: pix["qr_code_base64"],
        expires_at: parse_time(response["date_of_expiration"])
      )
    end

    # A notificação do Mercado Pago não carrega o status de forma confiável —
    # ela avisa "o pagamento X mudou" e espera que a aplicação consulte. Sem
    # isso, bastaria forjar um POST para marcar um pedido como pago.
    def payment_status(external_id:)
      require_access_token!

      response = get("/v1/payments/#{external_id}")
      STATUS_MAP.fetch(response["status"].to_s, "pending")
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

      status = payment_status(external_id: external_id)

      {
        event_id: "mp-#{external_id}-#{status}",
        external_id: external_id.to_s,
        status: status
      }
    end

    private

    def require_access_token!
      return if @access_token.present?

      raise ConfigurationError, "MERCADO_PAGO_ACCESS_TOKEN não configurado"
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

    def get(path)
      request = Net::HTTP::Get.new(path)
      perform(request)
    end

    def post(path, body:, headers: {})
      request = Net::HTTP::Post.new(path)
      headers.each { |key, value| request[key] = value }
      request.body = body.to_json
      perform(request)
    end

    def perform(request)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Content-Type"] = "application/json"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        # Sem o corpo da resposta na mensagem: ele pode ecoar dados do
        # pagamento, e esta exceção vai para o log.
        raise RequestFailed, "Mercado Pago respondeu #{response.code} em #{request.path}"
      end

      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      raise RequestFailed, "resposta ilegível do Mercado Pago em #{request.path}"
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
