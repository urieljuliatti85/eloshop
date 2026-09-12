require "net/http"
require "json"

module Marketplace
  # OAuth2 do Melhor Envio (ADR 005, Fase de frete real, Etapa 1). Mesmo
  # padrão do Mercado Pago (Marketplace::MercadoPagoOauth): cada vendedor
  # conecta a própria conta, tokens cifrados em Seller.
  #
  # Diferenças confirmadas na documentação oficial
  # (docs.melhorenvio.com.br/reference/solicitacao-do-token e
  # /reference/fluxo-de-autorização):
  # - sem PKCE (o Mercado Pago exige code_challenge, o Melhor Envio não)
  # - client_id é numérico, não string
  # - o token exchange não devolve identificador de conta/usuário — só
  #   access_token/refresh_token/expires_in/token_type — então não há como
  #   validar "o token renovado pertence à mesma conta" como se faz para o
  #   Mercado Pago (ver Seller#connect_melhor_envio! e
  #   Marketplace::MelhorEnvioAccessToken)
  class MelhorEnvioOauth
    class ConfigurationError < StandardError; end
    class RequestFailed < StandardError; end

    Credentials = Data.define(:access_token, :refresh_token, :expires_at)

    PRODUCTION_HOST = "melhorenvio.com.br"
    SANDBOX_HOST = "sandbox.melhorenvio.com.br"
    TOKEN_PATH = "/oauth/token"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    TRUE_VALUES = %w[1 true yes on].freeze

    def initialize(client_id: ENV["MELHOR_ENVIO_CLIENT_ID"],
                    client_secret: ENV["MELHOR_ENVIO_CLIENT_SECRET"],
                    redirect_uri: ENV["MELHOR_ENVIO_REDIRECT_URI"],
                    sandbox: ENV["MELHOR_ENVIO_SANDBOX"],
                    event_reporter: Rails.event)
      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @sandbox = TRUE_VALUES.include?(sandbox.to_s.downcase)
      @event_reporter = event_reporter
    end

    def configured?
      @client_id.present? && @client_secret.present? && @redirect_uri.present?
    end

    def sandbox?
      @sandbox
    end

    def authorization_url(state:)
      require_configuration!

      uri = URI("https://#{host}/oauth/authorize")
      uri.query = URI.encode_www_form(
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        response_type: "code",
        scope: "shipping-calculate",
        state: state
      )
      uri.to_s
    end

    def exchange(code:)
      require_configuration!

      request_credentials(
        {
          grant_type: "authorization_code",
          client_id: @client_id,
          client_secret: @client_secret,
          redirect_uri: @redirect_uri,
          code: code
        },
        failure_message: "Melhor Envio recusou a vinculação"
      )
    end

    def refresh(refresh_token:)
      require_configuration!

      request_credentials(
        {
          grant_type: "refresh_token",
          client_id: @client_id,
          client_secret: @client_secret,
          refresh_token: refresh_token
        },
        failure_message: "Melhor Envio recusou a renovação da conexão"
      )
    end

    private

    def host
      @sandbox ? SANDBOX_HOST : PRODUCTION_HOST
    end

    def request_credentials(body, failure_message:)
      payload = nil
      request = Net::HTTP::Post.new(TOKEN_PATH)
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        log_error_response(response)
        raise RequestFailed, "#{failure_message} (HTTP #{response.code})"
      end

      payload = JSON.parse(response.body.to_s)
      build_credentials(payload)
    rescue JSON::ParserError, KeyError, ArgumentError, TypeError
      log_invalid_payload(payload)
      raise RequestFailed, "Melhor Envio devolveu credenciais inválidas"
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise RequestFailed, "Não foi possível conectar ao Melhor Envio. Tente novamente."
    end

    # O HTTP 403 na vinculação (2026-09-12) não dizia nada além do código: a
    # exceção descartava o corpo, que é justamente onde o Melhor Envio explica
    # a recusa. Mesmo padrão e mesmo motivo do log de erro do gateway do
    # Mercado Pago, criado em 2026-09-08 para um 500 opaco — sem ele a
    # investigação vira dedução a partir do código de status.
    #
    # Loga só os campos de erro documentados (error, error_description,
    # message, hint), nunca o corpo inteiro: a resposta de sucesso deste
    # endpoint traz access_token/refresh_token, e um dia o de erro pode
    # ecoá-los (§43).
    def log_error_response(response)
      body = JSON.parse(response.body.to_s)
      @event_reporter.notify(
        "marketplace.melhor_envio_oauth.failed",
        failure_reason: "http_error",
        http_status: response.code,
        error: body["error"],
        error_description: body["error_description"],
        message: body["message"],
        hint: body["hint"]
      )
    rescue StandardError
      # Corpo não-JSON: em 2026-09-12 foi exatamente este caso, e registrar
      # só "corpo ilegível" custou um acesso por SSH ao contêiner para
      # descobrir que o 403 era `E-WAF-0003`, uma página de WAF servida pelo
      # load balancer antes da API. O trecho inicial identifica a camada que
      # respondeu — é a diferença entre "o provedor recusou" e "a requisição
      # nem chegou lá".
      begin
        @event_reporter.notify(
          "marketplace.melhor_envio_oauth.failed",
          failure_reason: "http_error",
          http_status: response.code,
          error: "corpo não-JSON",
          content_type: response["content-type"],
          server: response["server"],
          body_excerpt: body_excerpt(response)
        )
      rescue StandardError
        nil
      end
    end

    # Só o começo do corpo, sem marcação e sem quebras de linha. O limite
    # existe porque a página de erro pode ser longa, e a sanitização porque
    # este trecho vai para o log: não é lugar de HTML nem de conteúdo que o
    # provedor possa ecoar de volta (§43).
    BODY_EXCERPT_LIMIT = 300
    WHITESPACE = [ " ", "\t", "\n", "\r", "\f", "\v" ].freeze

    # Sem regex, de propósito. A versão anterior usava `<[^>]*>` e o CodeQL
    # apontou `rb/polynomial-redos` (PR #84): o corpo vem de terceiro — aqui,
    # de um WAF — e uma entrada com muitos `<` sem fechamento faz o
    # backtracking crescer com o tamanho (medido: 10,9 ms para 200 KB).
    # Truncar antes reduzia o custo, mas não convence a análise estática nem
    # elimina a classe do problema: a regex continua recebendo dado externo.
    #
    # A varredura abaixo é linear e sem backtracking — um caractere por vez,
    # alternando entre "dentro" e "fora" de uma tag, colapsando espaços no
    # mesmo passo. O `first` inicial mantém o trabalho limitado de qualquer
    # forma, com folga para a marcação que será descartada.
    def body_excerpt(response)
      source = response.body.to_s.first(BODY_EXCERPT_LIMIT * 4)
      out = +""
      inside_tag = false

      source.each_char do |char|
        case char
        when "<" then inside_tag = true
        when ">" then inside_tag = false
        else
          next if inside_tag

          if WHITESPACE.include?(char)
            out << " " unless out.end_with?(" ")
          else
            out << char
          end
        end
        break if out.length > BODY_EXCERPT_LIMIT
      end

      out.strip.first(BODY_EXCERPT_LIMIT)
    end

    def log_invalid_payload(payload)
      response_fields = if payload.is_a?(Hash)
        payload.keys.map { |key| key.to_s.first(100) }.sort.first(50)
      else
        []
      end

      @event_reporter.notify(
        "marketplace.melhor_envio_oauth.failed",
        failure_reason: "invalid_payload",
        response_fields: response_fields
      )
    rescue StandardError
      nil
    end

    def require_configuration!
      return if configured?

      raise ConfigurationError, "OAuth do Melhor Envio ainda não está configurado"
    end

    def build_credentials(payload)
      access_token = payload.fetch("access_token").to_s
      refresh_token = payload.fetch("refresh_token").to_s
      expires_in = Integer(payload.fetch("expires_in"))
      raise KeyError if access_token.blank? || refresh_token.blank? || expires_in <= 0

      Credentials.new(
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: Time.current + expires_in.seconds
      )
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
