require "net/http"
require "json"

module Marketplace
  class MercadoPagoOauth
    class ConfigurationError < StandardError; end
    class RequestFailed < StandardError; end

    Credentials = Data.define(:user_id, :access_token, :refresh_token, :expires_at, :live_mode, :test_account)

    AUTHORIZATION_URL = "https://auth.mercadopago.com.br/authorization"
    API_HOST = "api.mercadopago.com"
    TOKEN_PATH = "/oauth/token"
    USERS_ME_PATH = "/users/me"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    TRUE_VALUES = %w[1 true yes on].freeze

    def initialize(app_id: ENV["MERCADO_PAGO_MARKETPLACE_APP_ID"],
                   client_secret: ENV["MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET"],
                   redirect_uri: ENV["MERCADO_PAGO_MARKETPLACE_REDIRECT_URI"],
                   sandbox: ENV["MERCADO_PAGO_MARKETPLACE_SANDBOX"],
                   event_reporter: Rails.event)
      @app_id = app_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @sandbox = TRUE_VALUES.include?(sandbox.to_s.downcase)
      @event_reporter = event_reporter
    end

    def configured?
      @app_id.present? && @client_secret.present? && @redirect_uri.present?
    end

    def sandbox?
      @sandbox
    end

    def authorization_url(state:, code_challenge:)
      require_configuration!

      uri = URI(AUTHORIZATION_URL)
      uri.query = URI.encode_www_form(
        client_id: @app_id,
        response_type: "code",
        platform_id: "mp",
        state: state,
        redirect_uri: @redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      )
      uri.to_s
    end

    def exchange(code:, code_verifier:)
      require_configuration!

      form_data = {
        client_id: @app_id,
        client_secret: @client_secret,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: @redirect_uri,
        code_verifier: code_verifier
      }
      form_data[:test_token] = "true" if sandbox?

      request_credentials(form_data, failure_message: "Mercado Pago recusou a vinculação")
    end

    def refresh(refresh_token:)
      require_configuration!

      request_credentials(
        {
          client_id: @app_id,
          client_secret: @client_secret,
          grant_type: "refresh_token",
          refresh_token: refresh_token
        },
        failure_message: "Mercado Pago recusou a renovação da conexão"
      )
    end

    private

    def request_credentials(form_data, failure_message:)
      payload = nil
      request = Net::HTTP::Post.new(TOKEN_PATH)
      request["Accept"] = "application/json"
      request.set_form_data(form_data)

      response = http.request(request)
      raise RequestFailed, "#{failure_message} (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body.to_s)
      build_credentials(payload)
    rescue JSON::ParserError, KeyError, ArgumentError, TypeError
      log_invalid_payload(payload)
      raise RequestFailed, "Mercado Pago devolveu credenciais inválidas"
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise RequestFailed, "Não foi possível conectar ao Mercado Pago. Tente novamente."
    end

    def log_invalid_payload(payload)
      response_fields = if payload.is_a?(Hash)
        payload.keys.map { |key| key.to_s.first(100) }.sort.first(50)
      else
        []
      end

      @event_reporter.notify(
        "marketplace.mercado_pago_oauth.failed",
        failure_reason: "invalid_payload",
        response_fields: response_fields
      )
    rescue StandardError
      nil
    end

    def require_configuration!
      return if configured?

      raise ConfigurationError, "OAuth do Mercado Pago ainda não está configurado"
    end

    def build_credentials(payload)
      user_id = payload.fetch("user_id").to_s
      access_token = payload.fetch("access_token").to_s
      refresh_token = payload.fetch("refresh_token").to_s
      expires_in = Integer(payload.fetch("expires_in"))
      raise KeyError if user_id.blank? || access_token.blank? || refresh_token.blank? || expires_in <= 0

      Credentials.new(
        user_id: user_id,
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: Time.current + expires_in.seconds,
        live_mode: payload["live_mode"] == true,
        test_account: test_account?(access_token)
      )
    end

    # `live_mode` do token não serve para separar teste de produção: o Mercado
    # Pago devolve `true` também para TESTUSER, porque do lado deles a conta
    # transaciona. Quem distingue é a tag `test_user` em /users/me.
    #
    # `nil` quando a consulta falha — e não `false`, que afirmaria ser conta
    # real. Sem certeza, a aprovação não passa (ver Seller#approve!).
    def test_account?(access_token)
      request = Net::HTTP::Get.new(USERS_ME_PATH)
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body.to_s)["tags"].to_a.include?("test_user")
    rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
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
