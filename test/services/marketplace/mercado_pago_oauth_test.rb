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

      captured = stub_request({
        "user_id" => 123_456,
        "access_token" => "seller-test-access-token",
        "refresh_token" => "seller-test-refresh-token",
        "expires_in" => 15_552_000,
        "live_mode" => false
      }, oauth: oauth) { oauth.exchange(code: "sandbox-authorization-code") }

      body = Rack::Utils.parse_query(captured.body)
      assert oauth.sandbox?
      assert_equal "true", body["test_token"]
    end

    test "fails safely when configuration is absent" do
      oauth = MercadoPagoOauth.new(app_id: nil, client_secret: nil, redirect_uri: nil)

      assert_not oauth.configured?
      assert_raises(MercadoPagoOauth::ConfigurationError) do
        oauth.authorization_url(state: "state")
      end
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
