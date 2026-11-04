require "net/http"
require "json"

module Marketplace
  # OAuth 2.0 da SuperFrete (ADR 005). A documentação reserva o OAuth a
  # "operações com múltiplas lojas" — o caso da EloShop: cada ateliê autoriza
  # a própria conta e a própria carteira.
  #
  # Particularidades confirmadas na documentação oficial
  # (superfrete.readme.io/reference/solicitação-do-token):
  # - a autorização é uma rota com hash no app web (`/#/auth/authorize`), sem
  #   `response_type` nem `scope`, e o `state` é opcional — a EloShop envia e
  #   exige mesmo assim;
  # - o token **não expira** (`"expires": "never"`) e não há refresh;
  # - no sandbox, a troca do token vai para uma Cloud Function, não para
  #   `sandbox.superfrete.com` como o resto da API;
  # - a troca não devolve a conta: ela vem de `GET /api/v0/user`.
  class SuperfreteOauth
    class ConfigurationError < StandardError; end
    class RequestFailed < StandardError; end

    Account = Data.define(:id, :email)

    AUTHORIZE_URLS = {
      production: "https://web.superfrete.com/#/auth/authorize",
      sandbox: "https://sandbox.superfrete.com/#/auth/authorize"
    }.freeze
    TOKEN_URLS = {
      production: "https://api.superfrete.com/api/v0/oauth/token",
      sandbox: "https://us-central1-sandbox-api-superfrete.cloudfunctions.net/apiIntegrationOAuth/api/v0/oauth/token"
    }.freeze
    API_HOSTS = {
      production: "api.superfrete.com",
      sandbox: "sandbox.superfrete.com"
    }.freeze
    USER_PATH = "/api/v0/user"

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    TRUE_VALUES = %w[1 true yes on].freeze
    # A SuperFrete exige nome da aplicação e contato técnico no User-Agent.
    USER_AGENT = "EloShop (contato@eloshop.shop)".freeze

    # Ambiente configurado (sandbox ou produção). É a resposta única para
    # "qual SuperFrete esta instalação usa": a conexão grava o ambiente no
    # ateliê, e a cotação só vale quando os dois batem (Seller#superfrete_environment_current?).
    def self.sandbox?(value = ENV["SUPERFRETE_SANDBOX"])
      TRUE_VALUES.include?(value.to_s.downcase)
    end

    def initialize(client_id: ENV["SUPERFRETE_CLIENT_ID"],
                    client_secret: ENV["SUPERFRETE_CLIENT_SECRET"],
                    redirect_uri: ENV["SUPERFRETE_REDIRECT_URI"],
                    sandbox: ENV["SUPERFRETE_SANDBOX"],
                    http: nil)
      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @sandbox = self.class.sandbox?(sandbox)
      @http = http
    end

    def configured?
      @client_id.present? && @client_secret.present? && @redirect_uri.present?
    end

    def sandbox?
      @sandbox
    end

    # A query vai depois do `#`: é o app web (rota com hash) que lê os
    # parâmetros, então `URI` não serve para montar — ele os poria antes.
    def authorization_url(state:)
      require_configuration!

      query = URI.encode_www_form(client_id: @client_id, redirect_uri: @redirect_uri, state: state)
      "#{AUTHORIZE_URLS.fetch(environment)}?#{query}"
    end

    # Troca o `code` pelo token, servidor a servidor: o `client_secret` nunca
    # passa pelo navegador. A documentação pede o mesmo `state` do passo 1.
    def exchange(code:, state:)
      require_configuration!

      payload = post_json(
        URI(TOKEN_URLS.fetch(environment)),
        grant_type: "authorization_code",
        client_id: @client_id,
        client_secret: @client_secret,
        redirect_uri: @redirect_uri,
        code: code,
        state: state
      )
      access_token = payload["access_token"].to_s
      raise RequestFailed, "A SuperFrete devolveu credenciais inválidas." if access_token.blank?

      access_token
    end

    # A conta dona do token — e da carteira que paga as etiquetas.
    def account(access_token:)
      request = Net::HTTP::Get.new(USER_PATH)
      request["Authorization"] = "Bearer #{access_token}"
      payload = perform(URI("https://#{API_HOSTS.fetch(environment)}"), request)

      id = payload["id"].to_s
      raise RequestFailed, "A SuperFrete não informou a conta conectada." if id.blank?

      Account.new(id: id, email: payload["email"].to_s.presence)
    end

    private

    def environment
      @sandbox ? :sandbox : :production
    end

    def require_configuration!
      raise ConfigurationError, "A conexão com a SuperFrete ainda não está configurada." unless configured?
    end

    def post_json(uri, body)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      perform(uri, request)
    end

    # Sem o corpo da resposta na mensagem: na troca do token, ele pode trazer
    # o próprio token, e esta exceção chega ao flash e ao log.
    def perform(uri, request)
      request["Accept"] = "application/json"
      request["User-Agent"] = USER_AGENT

      response = http_for(uri).request(request)
      raise RequestFailed, "A SuperFrete recusou a conexão (HTTP #{response.code}). Tente novamente." unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      raise RequestFailed, "A SuperFrete devolveu uma resposta ilegível."
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise RequestFailed, "Não foi possível conectar à SuperFrete. Tente novamente."
    end

    def http_for(uri)
      return @http if @http

      Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.use_ssl = true
        client.open_timeout = OPEN_TIMEOUT
        client.read_timeout = READ_TIMEOUT
      end
    end
  end
end
