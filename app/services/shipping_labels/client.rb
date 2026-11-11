require "net/http"
require "json"

module ShippingLabels
  # Chamadas de etiqueta à SuperFrete com o token da conta do ateliê. Separado
  # da cotação do checkout (Shipping::Providers::Superfrete) porque aqui o
  # contrato é outro: timeouts maiores (roda no painel e em job, não no
  # checkout) e erros que distinguem "recusado" de "não sei o que aconteceu".
  #
  # Comportamento real verificado no sandbox em 2026-11-05 (docs/shipping.md,
  # "Etiqueta e rastreio: o que o sandbox mostrou"). Duas regras de
  # privacidade valem para tudo aqui:
  #
  # * a consulta do pedido devolve dados pessoais da conta do ateliê (CPF,
  #   nascimento, IPs) em `service_calculated`: só os campos listados em
  #   `order_info` saem desta classe;
  # * nenhum corpo de resposta vai para exceção ou log, só o código e a
  #   mensagem curta que a SuperFrete escreveu para o usuário.
  class Client
    # Base: qualquer falha.
    class Error < StandardError; end
    # A SuperFrete respondeu e recusou (4xx). O que ela pediu não aconteceu.
    class Rejected < Error; end
    # Token revogado do lado da SuperFrete.
    class Unauthorized < Rejected; end
    # Timeout, 5xx ou resposta ilegível: o efeito pode ou não ter acontecido.
    # Um 500 do checkout não prova que nada foi cobrado.
    class Ambiguous < Error; end

    Option = Data.define(:service_code, :service_name, :carrier, :price_cents, :delivery_days,
      :height_cm, :width_cm, :length_cm, :weight_grams)

    OrderInfo = Data.define(:id, :status, :tracking, :price_cents, :service_code, :print_url) do
      # "generated"/"released" (paga), "posted", "delivered": já houve cobrança.
      def paid?
        %w[released generated posted delivered].include?(status)
      end

      def pending?
        status == "pending"
      end

      def cancelled?
        %w[canceled cancelled].include?(status)
      end

      def posted?
        %w[posted delivered].include?(status)
      end
    end

    # Limite de etiquetas da conta (regra antifraude da SuperFrete para conta
    # nova; cresce sozinho conforme a conta posta): `pending` são as pagas
    # aguardando postagem, `available` quantas ainda podem ser pagas.
    Limits = Data.define(:pending, :available) do
      def exhausted?
        available <= 0
      end
    end

    # Correios: PAC, SEDEX e Mini Envios, os mesmos da cotação do checkout.
    SERVICE_CODES = [ 1, 2, 17 ].freeze
    OPEN_TIMEOUT = 5
    # O job pode esperar; a requisição do painel (cotar, imprimir, cancelar)
    # não: o Puma tem 2 threads e divide o processo com o Solid Queue.
    READ_TIMEOUT = 20
    INTERACTIVE_READ_TIMEOUT = 8
    PLATFORM = "EloShop".freeze

    def initialize(seller:, http: nil, read_timeout: READ_TIMEOUT)
      @seller = seller
      @http = http
      @read_timeout = read_timeout
    end

    def quote(origin_zip_code:, destination_zip_code:, height_cm:, width_cm:, length_cm:, weight_grams:)
      response = request(:post, "/api/v0/calculator", {
        from: { postal_code: origin_zip_code },
        to: { postal_code: destination_zip_code },
        services: SERVICE_CODES.join(","),
        options: { own_hand: false, receipt: false, insurance_value: 0, use_insurance_value: false },
        products: [ { quantity: 1, height: height_cm, width: width_cm, length: length_cm, weight: (weight_grams / 1000.0).round(3) } ]
      })
      raise Ambiguous, "resposta inesperada da cotação" unless response.is_a?(Array)

      response.filter_map { |option| build_option(option) }
    end

    # Cria o pedido na SuperFrete, sem cobrar. Devolve o id e o preço.
    def create_cart(payload)
      response = request(:post, "/api/v0/cart", payload.merge(platform: PLATFORM))
      id = response.is_a?(Hash) && response["id"].presence
      raise Ambiguous, "pedido criado sem id na resposta" unless id

      { id: id.to_s, price_cents: cents(response["price"]) }
    end

    # Paga com o saldo da carteira. Sem saldo, a SuperFrete responde 409
    # (Rejected) e nada é cobrado; repetir não tem efeito.
    def checkout(provider_order_id)
      response = request(:post, "/api/v0/checkout", { orders: [ provider_order_id ] })
      purchased = response.is_a?(Hash) && Array(response.dig("purchase", "orders")).find { |order| order["id"].to_s == provider_order_id }
      raise Ambiguous, "pagamento sem confirmação na resposta" unless purchased && response.dig("purchase", "status") == "paid"

      { tracking: purchased["tracking"].presence, price_cents: cents(purchased["price"]) }
    end

    def order_info(provider_order_id)
      response = request(:get, "/api/v0/order/info/#{ERB::Util.url_encode(provider_order_id)}")
      raise Ambiguous, "consulta do pedido sem id" unless response.is_a?(Hash) && response["id"].present?

      OrderInfo.new(
        id: response["id"].to_s,
        status: response["status"].to_s,
        tracking: response["tracking"].presence,
        price_cents: cents(response["price"]),
        service_code: response["service_id"],
        print_url: response.dig("print", "url").presence
      )
    end

    # Só antes da postagem; o valor volta para a carteira do ateliê. Repetir
    # num pedido já cancelado responde 409 (Rejected): quem chama confere
    # pela consulta.
    def cancel(provider_order_id, reason:)
      request(:post, "/api/v0/order/cancel", { order: { id: provider_order_id, description: reason } })
      true
    end

    # `GET /api/v0/user` traz também os dados pessoais da conta do ateliê: só
    # os dois números do limite saem daqui. Sem eles na resposta, nil — a tela
    # segue sem o aviso.
    def label_limits
      response = request(:get, "/api/v0/user")
      limits = response["limits"] if response.is_a?(Hash)
      return unless limits.is_a?(Hash)

      Limits.new(pending: Integer(limits["shipments"] || 0), available: Integer(limits["shipments_available"]))
    rescue ArgumentError, TypeError
      nil
    end

    # Registra o webhook de rastreio na conta do ateliê, com o token OAuth dele
    # (confirmado pela SuperFrete em 2026-11-11). O `secret_token` que assina
    # as notificações só volta nesta resposta.
    def create_webhook(name:, url:, events:)
      response = request(:post, "/api/v0/webhook", { name: name, url: url, events: events })
      id = response.is_a?(Hash) && response["id"].presence
      secret = response.is_a?(Hash) && response["secret_token"].presence
      raise Ambiguous, "webhook criado sem id ou segredo na resposta" unless id && secret

      { id: id.to_s, secret: secret.to_s }
    end

    def delete_webhook(webhook_id)
      request(:delete, "/api/v0/webhook/#{ERB::Util.url_encode(webhook_id)}")
      true
    end

    private

    def build_option(option)
      return unless option.is_a?(Hash) && !option["has_error"] && option["error"].blank?
      return unless SERVICE_CODES.include?(option["id"])

      package = Array(option["packages"]).first || {}
      dimensions = package["dimensions"] || {}
      Option.new(
        service_code: option["id"],
        service_name: option["name"].to_s,
        carrier: option.dig("company", "name").to_s.presence || "Correios",
        price_cents: cents(option["price"]),
        delivery_days: Integer(option["delivery_time"]),
        height_cm: Integer(dimensions["height"]),
        width_cm: Integer(dimensions["width"]),
        length_cm: Integer(dimensions["length"]),
        weight_grams: (BigDecimal(package["weight"].to_s) * 1000).round.to_i
      )
    rescue ArgumentError, TypeError
      nil
    end

    def cents(value)
      return if value.blank?

      (BigDecimal(value.to_s) * 100).round.to_i
    rescue ArgumentError
      nil
    end

    def request(method, path, body = nil)
      token = @seller.superfrete_access_token
      raise Unauthorized, "a conta SuperFrete do ateliê não está conectada" if token.blank?

      request = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method).new(path)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request["User-Agent"] = Marketplace::SuperfreteOauth::USER_AGENT
      request.body = body.to_json if body

      response = http.request(request)
      parsed = parse(response.body)

      case response
      when Net::HTTPSuccess
        parsed
      when Net::HTTPUnauthorized
        @seller.mark_superfrete_revoked!
        Rails.event.notify("shipping.provider_unauthorized", provider: "superfrete", seller_id: @seller.id)
        raise Unauthorized, "a SuperFrete recusou o acesso da conta conectada; reconecte a SuperFrete"
      when Net::HTTPClientError
        raise Rejected, user_message(parsed) || "a SuperFrete recusou o pedido (#{response.code})"
      else
        raise Ambiguous, "SuperFrete respondeu #{response.code}"
      end
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise Ambiguous, "sem resposta da SuperFrete"
    end

    def parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      nil
    end

    # A mensagem que a SuperFrete escreveu para o usuário ("Sem saldo na
    # carteira! ..."), curta, sem o resto do corpo.
    def user_message(parsed)
      return unless parsed.is_a?(Hash)

      message = parsed["message"].presence
      details = parsed["errors"].is_a?(Hash) ? parsed["errors"].values.flatten.compact.join(" ") : nil
      text = [ (message unless message == "Ocorreu um ou mais erros."), details ].compact_blank.join(" ")
      text.truncate(300).presence
    end

    def host
      @seller.superfrete_sandbox? ? Shipping::Providers::Superfrete::HOSTS[:sandbox] : Shipping::Providers::Superfrete::HOSTS[:production]
    end

    def http
      @http ||= Net::HTTP.new(host, 443).tap do |client|
        client.use_ssl = true
        client.open_timeout = OPEN_TIMEOUT
        client.read_timeout = @read_timeout
      end
    end
  end
end
