require "test_helper"

module Shipping
  class ProvidersTest < ActiveSupport::TestCase
    test "returns the SuperFrete provider for a seller connected to it" do
      seller = sellers(:approved)
      connect_superfrete(seller)

      assert_instance_of Providers::Superfrete, Providers.for(seller)
    end

    test "returns nothing for a seller without a connected provider" do
      assert_nil Providers.for(sellers(:approved))
      assert_nil Providers.for(nil)
    end

    test "returns nothing when remote quotes are disabled in the environment" do
      seller = sellers(:approved)
      connect_superfrete(seller)

      with_remote_quotes_enabled(false) do
        assert_not Providers.enabled?
        assert_nil Providers.for(seller)
      end
    end

    test "every provider error is a Providers::Unavailable" do
      assert_operator Providers::Superfrete::Unavailable, :<, Providers::Unavailable
    end

    private

    def connect_superfrete(seller)
      seller.connect_superfrete!(access_token: "token", account: Marketplace::SuperfreteOauth::Account.new(id: "sf-1", email: nil))
    end

    def with_remote_quotes_enabled(value)
      previous = Rails.configuration.x.shipping.remote_quotes_enabled
      Rails.configuration.x.shipping.remote_quotes_enabled = value
      yield
    ensure
      Rails.configuration.x.shipping.remote_quotes_enabled = previous
    end
  end
end
