require "test_helper"

module Marketplace
  class MelhorEnvioAccessTokenTest < ActiveSupport::TestCase
    def credentials(access_token:, refresh_token:, expires_at:)
      MelhorEnvioOauth::Credentials.new(access_token: access_token, refresh_token: refresh_token, expires_at: expires_at)
    end

    test "returns a current token without contacting OAuth" do
      seller = sellers(:approved)
      seller.connect_melhor_envio!(credentials(access_token: "current", refresh_token: "refresh", expires_at: 1.day.from_now))
      oauth = Object.new
      oauth.define_singleton_method(:refresh) { |**| raise "não deveria renovar" }

      assert_equal "current", MelhorEnvioAccessToken.new(seller: seller, oauth: oauth).call
    end

    test "renews and persists an expiring token" do
      seller = sellers(:approved)
      seller.connect_melhor_envio!(credentials(access_token: "old", refresh_token: "old-refresh", expires_at: 1.minute.from_now))
      renewed = credentials(access_token: "new", refresh_token: "new-refresh", expires_at: 30.days.from_now)
      oauth = Object.new
      oauth.define_singleton_method(:refresh) do |refresh_token:|
        raise "token inesperado" unless refresh_token == "old-refresh"

        renewed
      end

      assert_equal "new", MelhorEnvioAccessToken.new(seller: seller, oauth: oauth).call
      assert_equal "new", seller.reload.melhor_envio_access_token
      assert_equal "new-refresh", seller.melhor_envio_refresh_token
    end

    test "raises when the seller has not connected Melhor Envio" do
      seller = sellers(:approved)
      oauth = Object.new

      assert_raises(MelhorEnvioOauth::ConfigurationError) do
        MelhorEnvioAccessToken.new(seller: seller, oauth: oauth).call
      end
    end
  end
end
