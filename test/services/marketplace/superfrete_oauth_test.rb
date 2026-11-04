require "test_helper"

module Marketplace
  # HTTP é stubado: estes testes verificam o contrato do adapter com a
  # documentação oficial (superfrete.readme.io/reference/solicitação-do-token),
  # não a API real.
  class SuperfreteOauthTest < ActiveSupport::TestCase
    REDIRECT_URI = "https://eloshop.example/painel/superfrete/callback".freeze

    test "authorization URL is the web app hash route with the query after the hash" do
      url = oauth.authorization_url(state: "random-state")
      base, query = url.split("?", 2)
      params = Rack::Utils.parse_query(query)

      assert_equal "https://web.superfrete.com/#/auth/authorize", base
      assert_equal({ "client_id" => "client-id", "redirect_uri" => REDIRECT_URI, "state" => "random-state" }, params)
    end

    test "sandbox authorizes on the sandbox web app" do
      assert oauth(sandbox: "true").sandbox?
      assert_match %r{\Ahttps://sandbox\.superfrete\.com/#/auth/authorize\?}, oauth(sandbox: "true").authorization_url(state: "s")
    end

    test "refuses to start without configuration" do
      assert_raises(SuperfreteOauth::ConfigurationError) { oauth(client_secret: nil).authorization_url(state: "s") }
      assert_not oauth(redirect_uri: "").configured?
    end

    test "exchanges the code server-to-server and returns the token" do
      captured = []
      token = oauth(http: fake_http({ "access_token" => "seller-token", "expires" => "never", "token_type" => "Bearer" }, captured)).exchange(code: "auth-code", state: "the-state")

      assert_equal "seller-token", token
      request = captured.sole
      assert_equal "/api/v0/oauth/token", request.path
      assert_equal SuperfreteOauth::USER_AGENT, request["User-Agent"]
      body = JSON.parse(request.body)
      assert_equal({ "grant_type" => "authorization_code", "client_id" => "client-id", "client_secret" => "client-secret",
        "redirect_uri" => REDIRECT_URI, "code" => "auth-code", "state" => "the-state" }, body)
    end

    # No sandbox, a troca do token não vai para sandbox.superfrete.com.
    test "each environment exchanges the token on its documented endpoint" do
      assert_equal "api.superfrete.com", URI(SuperfreteOauth::TOKEN_URLS[:production]).host
      assert_equal "us-central1-sandbox-api-superfrete.cloudfunctions.net", URI(SuperfreteOauth::TOKEN_URLS[:sandbox]).host
      assert_equal "/apiIntegrationOAuth/api/v0/oauth/token", URI(SuperfreteOauth::TOKEN_URLS[:sandbox]).path
    end

    test "rejects a token response without access_token" do
      assert_raises(SuperfreteOauth::RequestFailed) { oauth(http: fake_http({ "token_type" => "Bearer" })).exchange(code: "c", state: "s") }
    end

    test "an HTTP error fails without leaking the response body" do
      http = Object.new
      http.define_singleton_method(:request) do |_request|
        Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap do |response|
          response.define_singleton_method(:body) { '{"error":"invalid_client","access_token":"vazado"}' }
        end
      end

      error = assert_raises(SuperfreteOauth::RequestFailed) { oauth(http: http).exchange(code: "c", state: "s") }
      assert_not_includes error.message, "vazado"
    end

    test "a network failure becomes RequestFailed" do
      http = Object.new
      http.define_singleton_method(:request) { |_request| raise Net::ReadTimeout }

      assert_raises(SuperfreteOauth::RequestFailed) { oauth(http: http).exchange(code: "c", state: "s") }
    end

    test "reads the connected account with the token" do
      captured = []
      account = oauth(http: fake_http({ "id" => 42, "email" => "atelie@example.com", "balance" => 10.5 }, captured)).account(access_token: "seller-token")

      assert_equal SuperfreteOauth::Account.new(id: "42", email: "atelie@example.com"), account
      assert_equal "/api/v0/user", captured.sole.path
      assert_equal "Bearer seller-token", captured.sole["Authorization"]
    end

    test "rejects an account response without id" do
      assert_raises(SuperfreteOauth::RequestFailed) { oauth(http: fake_http({ "email" => "x@example.com" })).account(access_token: "t") }
    end

    private

    def oauth(**overrides)
      SuperfreteOauth.new(**{ client_id: "client-id", client_secret: "client-secret", redirect_uri: REDIRECT_URI, sandbox: nil }.merge(overrides))
    end

    def fake_http(payload, captured = [])
      Object.new.tap do |http|
        http.define_singleton_method(:request) do |request|
          captured << request
          Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
            response.define_singleton_method(:body) { payload.to_json }
          end
        end
      end
    end
  end
end
