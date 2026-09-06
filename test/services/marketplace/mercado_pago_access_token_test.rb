require "test_helper"

module Marketplace
  class MercadoPagoAccessTokenTest < ActiveSupport::TestCase
    def credentials(access_token:, refresh_token:, expires_at:)
      MercadoPagoOauth::Credentials.new(
        user_id: "seller-123",
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: expires_at,
        live_mode: true,
      test_account: false
      )
    end

    test "returns a current token without contacting OAuth" do
      seller = sellers(:approved)
      seller.connect_mercado_pago!(credentials(access_token: "current", refresh_token: "refresh", expires_at: 1.day.from_now))
      oauth = Object.new
      oauth.define_singleton_method(:refresh) { |**| raise "não deveria renovar" }

      assert_equal "current", MercadoPagoAccessToken.new(seller: seller, oauth: oauth).call
    end

    test "renews and persists an expiring token" do
      seller = sellers(:approved)
      seller.connect_mercado_pago!(credentials(access_token: "old", refresh_token: "old-refresh", expires_at: 1.minute.from_now))
      renewed = credentials(access_token: "new", refresh_token: "new-refresh", expires_at: 180.days.from_now)
      oauth = Object.new
      oauth.define_singleton_method(:refresh) do |refresh_token:|
        raise "token inesperado" unless refresh_token == "old-refresh"

        renewed
      end

      assert_equal "new", MercadoPagoAccessToken.new(seller: seller, oauth: oauth).call
      assert_equal "new", seller.reload.mercado_pago_access_token
      assert_equal "new-refresh", seller.mercado_pago_refresh_token
    end

    test "rejects a refreshed token belonging to another account" do
      seller = sellers(:approved)
      seller.connect_mercado_pago!(credentials(access_token: "old", refresh_token: "old-refresh", expires_at: 1.minute.from_now))
      foreign = Marketplace::MercadoPagoOauth::Credentials.new(
        user_id: "other-seller",
        access_token: "foreign",
        refresh_token: "foreign-refresh",
        expires_at: 180.days.from_now,
        live_mode: true,
      test_account: false
      )
      oauth = Object.new
      oauth.define_singleton_method(:refresh) { |**| foreign }

      assert_raises(MercadoPagoOauth::RequestFailed) do
        MercadoPagoAccessToken.new(seller: seller, oauth: oauth).call
      end
      assert_equal "old", seller.reload.mercado_pago_access_token
    end
  end
end
