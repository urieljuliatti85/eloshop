require "test_helper"

module Marketplace
  class MercadoPagoOauthTest < ActiveSupport::TestCase
    setup do
      @oauth = MercadoPagoOauth.new(
        app_id: "app-123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/mercado-pago/callback"
      )
    end

    test "authorization URL includes the documented marketplace parameters" do
      uri = URI(@oauth.authorization_url(state: "random-state"))
      query = Rack::Utils.parse_query(uri.query)

      assert_equal "auth.mercadopago.com.br", uri.host
      assert_equal "app-123", query["client_id"]
      assert_equal "code", query["response_type"]
      assert_equal "mp", query["platform_id"]
      assert_equal "random-state", query["state"]
      assert_equal "https://eloshop.example/painel/mercado-pago/callback", query["redirect_uri"]
    end

    test "exchange returns the seller identifiers and token expiration" do
      captured = stub_request({
        "user_id" => 123_456,
        "access_token" => "seller-access-token",
        "refresh_token" => "seller-refresh-token",
        "expires_in" => 15_552_000,
        "live_mode" => true
      }) do
        credentials = @oauth.exchange(code: "authorization-code")

        assert_equal "123456", credentials.user_id
        assert_equal "seller-access-token", credentials.access_token
        assert_equal "seller-refresh-token", credentials.refresh_token
        assert credentials.live_mode
        assert_in_delta 180.days.from_now, credentials.expires_at, 2.seconds
      end

      body = Rack::Utils.parse_query(captured.body)
      assert_equal "authorization_code", body["grant_type"]
      assert_equal "authorization-code", body["code"]
      assert_equal "client-secret", body["client_secret"]
      assert_nil body["test_token"]
    end

    test "sandbox exchange requests a test token explicitly" do
      oauth = MercadoPagoOauth.new(
        app_id: "app-123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/mercado-pago/callback",
        sandbox: "true"
      )

      credentials = nil
      captured = stub_request({
        "user_id" => 123_456,
        "access_token" => "seller-test-access-token",
        "refresh_token" => "seller-test-refresh-token",
        "expires_in" => 15_552_000
      }, oauth: oauth) { credentials = oauth.exchange(code: "sandbox-authorization-code") }

      body = Rack::Utils.parse_query(captured.body)
      assert oauth.sandbox?
      assert_equal "true", body["test_token"]
      assert_not credentials.live_mode
    end

    test "refresh exchanges the stored refresh token" do
      captured = stub_request({
        "user_id" => 123_456,
        "access_token" => "renewed-access-token",
        "refresh_token" => "renewed-refresh-token",
        "expires_in" => 15_552_000,
        "live_mode" => true
      }) { @oauth.refresh(refresh_token: "old-refresh-token") }

      body = Rack::Utils.parse_query(captured.body)
      assert_equal "refresh_token", body["grant_type"]
      assert_equal "old-refresh-token", body["refresh_token"]
      assert_equal "client-secret", body["client_secret"]
    end

    test "fails safely when configuration is absent" do
      oauth = MercadoPagoOauth.new(app_id: nil, client_secret: nil, redirect_uri: nil)

      assert_not oauth.configured?
      assert_raises(MercadoPagoOauth::ConfigurationError) do
        oauth.authorization_url(state: "state")
      end
    end

    test "logs only response field names when credentials are invalid" do
      remote_payload = {
        "user_id" => 123_456,
        "access_token" => "secret-access-token",
        "expires_in" => 15_552_000,
        "live_mode" => false
      }
      events = []
      event_reporter = Object.new
      event_reporter.define_singleton_method(:notify) { |name, **payload| events << [ name, payload ] }
      oauth = MercadoPagoOauth.new(
        app_id: "app-123",
        client_secret: "client-secret",
        redirect_uri: "https://eloshop.example/painel/mercado-pago/callback",
        event_reporter: event_reporter
      )

      assert_raises(MercadoPagoOauth::RequestFailed) do
        stub_request(remote_payload, oauth: oauth) { oauth.exchange(code: "authorization-code") }
      end

      name, payload = events.fetch(0)
      assert_equal "marketplace.mercado_pago_oauth.failed", name
      assert_equal "invalid_payload", payload[:failure_reason]
      assert_equal %w[access_token expires_in live_mode user_id], payload[:response_fields]
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

      error = assert_raises(MercadoPagoOauth::RequestFailed) do
        @oauth.exchange(code: "bad-code")
      end
    assert_not_includes error.message, "leaked"
  end

  test "translates network failures without leaking internals" do
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| raise Net::OpenTimeout, "internal host details" }
    @oauth.instance_variable_set(:@http, fake_http)

    error = assert_raises(MercadoPagoOauth::RequestFailed) do
      @oauth.exchange(code: "authorization-code")
    end
    assert_not_includes error.message, "internal host details"
  end

    # `live_mode` vem `true` também para TESTUSER: quem distingue é a tag.
    test "exchange marks a TESTUSER account as a test account" do
      stub_request(token_payload, tags: %w[user_product_seller test_user normal]) do
        assert @oauth.exchange(code: "authorization-code").test_account
      end
    end

    test "exchange marks a real account as not a test account" do
      stub_request(token_payload, tags: %w[user_product_seller normal]) do
        assert_equal false, @oauth.exchange(code: "authorization-code").test_account
      end
    end

    # Sem resposta do /users/me fica `nil`, e não `false`: afirmar que é conta
    # real sem ter verificado é justamente o erro que esta detecção corrige.
    test "exchange leaves the account type unknown when the lookup fails" do
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        if request.path == MercadoPagoOauth::USERS_ME_PATH
          Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
        else
          Net::HTTPOK.new("1.1", "200", "OK").tap do |r|
            payload = { "user_id" => 1, "access_token" => "a", "refresh_token" => "b", "expires_in" => 100, "live_mode" => true }
            r.define_singleton_method(:body) { payload.to_json }
          end
        end
      end
      @oauth.instance_variable_set(:@http, fake_http)

      assert_nil @oauth.exchange(code: "authorization-code").test_account
    end

    private

    def token_payload
      {
        "user_id" => 123_456,
        "access_token" => "seller-access-token",
        "refresh_token" => "seller-refresh-token",
        "expires_in" => 15_552_000,
        "live_mode" => true
      }
    end

    # Duas chamadas saem numa troca de token: o POST em /oauth/token e o GET
    # em /users/me, que descobre se a conta é de teste. O helper devolve a do
    # token — é dela que os testes verificam os parâmetros —, e responde ao
    # /users/me com as tags pedidas.
    def stub_request(payload, oauth: @oauth, tags: [])
      captured = nil
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured = request unless request.path == MercadoPagoOauth::USERS_ME_PATH

        body = request.path == MercadoPagoOauth::USERS_ME_PATH ? { "tags" => tags } : payload
        Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
          response.define_singleton_method(:body) { body.to_json }
        end
      end
      oauth.instance_variable_set(:@http, fake_http)

      yield
      captured
    end
  end
end
