require "test_helper"

module Marketplace
  # HTTP é stubado: estes testes verificam o contrato do adapter, não a API
  # do Melhor Envio. A verificação contra o sandbox real depende de
  # credenciais e ainda não foi feita — mesma situação do Mercado Pago.
  class MelhorEnvioOauthTest < ActiveSupport::TestCase
    setup do
      @oauth = MelhorEnvioOauth.new(
        client_id: "123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/melhor-envio/callback"
      )
    end

    test "authorization URL includes the documented parameters" do
      uri = URI(@oauth.authorization_url(state: "random-state"))
      query = Rack::Utils.parse_query(uri.query)

      assert_equal "melhorenvio.com.br", uri.host
      assert_equal "123", query["client_id"]
      assert_equal "code", query["response_type"]
      assert_equal "shipping-calculate", query["scope"]
      assert_equal "random-state", query["state"]
      assert_equal "https://eloshop.example/painel/melhor-envio/callback", query["redirect_uri"]
    end

    test "sandbox uses the sandbox host" do
      oauth = MelhorEnvioOauth.new(
        client_id: "123", client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/melhor-envio/callback", sandbox: "true"
      )

      uri = URI(oauth.authorization_url(state: "state"))

      assert oauth.sandbox?
      assert_equal "sandbox.melhorenvio.com.br", uri.host
    end

    test "exchange returns the token and expiration" do
      captured = stub_request({
        "token_type" => "Bearer",
        "access_token" => "seller-access-token",
        "refresh_token" => "seller-refresh-token",
        "expires_in" => 2_592_000
      }) do
        credentials = @oauth.exchange(code: "authorization-code")

        assert_equal "seller-access-token", credentials.access_token
        assert_equal "seller-refresh-token", credentials.refresh_token
        assert_in_delta 30.days.from_now, credentials.expires_at, 2.seconds
      end

      body = JSON.parse(captured.body)
      assert_equal "authorization_code", body["grant_type"]
      assert_equal "authorization-code", body["code"]
      assert_equal "client-secret", body["client_secret"]
      assert_equal "123", body["client_id"]
    end

    test "refresh exchanges the stored refresh token" do
      captured = stub_request({
        "token_type" => "Bearer",
        "access_token" => "renewed-access-token",
        "refresh_token" => "renewed-refresh-token",
        "expires_in" => 2_592_000
      }) { @oauth.refresh(refresh_token: "old-refresh-token") }

      body = JSON.parse(captured.body)
      assert_equal "refresh_token", body["grant_type"]
      assert_equal "old-refresh-token", body["refresh_token"]
      assert_equal "client-secret", body["client_secret"]
    end

    test "fails safely when configuration is absent" do
      oauth = MelhorEnvioOauth.new(client_id: nil, client_secret: nil, redirect_uri: nil)

      assert_not oauth.configured?
      assert_raises(MelhorEnvioOauth::ConfigurationError) do
        oauth.authorization_url(state: "state")
      end
    end

    test "logs only response field names when credentials are invalid" do
      remote_payload = { "token_type" => "Bearer", "access_token" => "secret-access-token", "expires_in" => 2_592_000 }
      events = []
      event_reporter = Object.new
      event_reporter.define_singleton_method(:notify) { |name, **payload| events << [ name, payload ] }
      oauth = MelhorEnvioOauth.new(
        client_id: "123", client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/melhor-envio/callback",
        event_reporter: event_reporter
      )

      assert_raises(MelhorEnvioOauth::RequestFailed) do
        stub_request(remote_payload, oauth: oauth) { oauth.exchange(code: "authorization-code") }
      end

      name, payload = events.fetch(0)
      assert_equal "marketplace.melhor_envio_oauth.failed", name
      assert_equal "invalid_payload", payload[:failure_reason]
      assert_equal %w[access_token expires_in token_type], payload[:response_fields]
      assert_not_includes payload.to_s, "secret-access-token"
    end

    test "does not include a remote response body in an error" do
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |_request|
        Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap do |response|
          response.define_singleton_method(:body) { '{"access_token":"leaked"}' }
        end
      end
      @oauth.instance_variable_set(:@http, fake_http)

      error = assert_raises(MelhorEnvioOauth::RequestFailed) do
        @oauth.exchange(code: "bad-code")
      end
      assert_not_includes error.message, "leaked"
    end

    # O HTTP 403 de 2026-09-12 chegou sem explicação porque o corpo da
    # resposta era descartado — e é nele que o Melhor Envio diz o motivo.
    test "logs the provider error fields on an HTTP failure" do
      events = []
      reporter = Object.new
      reporter.define_singleton_method(:notify) { |name, **payload| events << [ name, payload ] }
      oauth = MelhorEnvioOauth.new(
        client_id: "123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/melhor-envio/callback",
        event_reporter: reporter
      )
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |_request|
        Net::HTTPForbidden.new("1.1", "403", "Forbidden").tap do |response|
          response.define_singleton_method(:body) do
            '{"error":"invalid_scope","error_description":"escopo nao autorizado","access_token":"leaked"}'
          end
        end
      end
      oauth.instance_variable_set(:@http, fake_http)

      assert_raises(MelhorEnvioOauth::RequestFailed) { oauth.exchange(code: "bad-code") }

      name, payload = events.last
      assert_equal "marketplace.melhor_envio_oauth.failed", name
      assert_equal "http_error", payload[:failure_reason]
      assert_equal "403", payload[:http_status]
      assert_equal "invalid_scope", payload[:error]
      assert_equal "escopo nao autorizado", payload[:error_description]
      # O corpo pode trazer credencial; só os campos de erro são registrados.
      assert_not_includes payload.to_s, "leaked"
    end

    test "records the status when the error body is unreadable" do
      events = []
      reporter = Object.new
      reporter.define_singleton_method(:notify) { |name, **payload| events << [ name, payload ] }
      oauth = MelhorEnvioOauth.new(
        client_id: "123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/melhor-envio/callback",
        event_reporter: reporter
      )
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |_request|
        Net::HTTPForbidden.new("1.1", "403", "Forbidden").tap do |response|
          response.define_singleton_method(:body) { "<html>proxy error</html>" }
        end
      end
      oauth.instance_variable_set(:@http, fake_http)

      assert_raises(MelhorEnvioOauth::RequestFailed) { oauth.exchange(code: "bad-code") }

      name, payload = events.last
      assert_equal "marketplace.melhor_envio_oauth.failed", name
      assert_equal "403", payload[:http_status]
      assert_equal "corpo ilegível", payload[:error]
    end

    test "translates network failures without leaking internals" do
      fake_http = Object.new
      fake_http.define_singleton_method(:request) { |_request| raise Net::OpenTimeout, "internal host details" }
      @oauth.instance_variable_set(:@http, fake_http)

      error = assert_raises(MelhorEnvioOauth::RequestFailed) do
        @oauth.exchange(code: "authorization-code")
      end
      assert_not_includes error.message, "internal host details"
    end

    private

    def stub_request(payload, oauth: @oauth)
      captured = nil
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured = request
        Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
          response.define_singleton_method(:body) { payload.to_json }
        end
      end
      oauth.instance_variable_set(:@http, fake_http)

      yield
      captured
    end
  end
end
