require "test_helper"

module ShippingLabels
  class WebhookTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper

    setup do
      prepare_label_scenario
      @client = FakeClient.new
    end

    test "registers the tracking events at the seller's account and keeps the secret encrypted" do
      assert Webhook.new(@seller, client: @client).register

      args = @client.calls.find { |call| call.first == :create_webhook }.last
      assert_equal Webhook::EVENTS, args[:events]
      assert_match %r{/webhooks/superfrete/#{Regexp.escape(@seller.reload.superfrete_webhook_key)}\z}, args[:url]
      assert_equal "sf-webhook-1", @seller.superfrete_webhook_id
      assert_equal "a" * 64, @seller.superfrete_webhook_secret
      assert_not_includes @seller.superfrete_webhook_secret_ciphertext, "a" * 64
    end

    test "registering again creates the new webhook before deleting the old one, with a new key" do
      Webhook.new(@seller, client: @client).register
      old_key = @seller.reload.superfrete_webhook_key
      @client.create_webhook_result = { id: "sf-webhook-2", secret: "b" * 64 }

      Webhook.new(@seller, client: @client).register

      assert_equal %i[create_webhook create_webhook delete_webhook], @client.calls.map(&:first)
      assert_equal "sf-webhook-1", @client.calls.last.last
      assert_not_equal old_key, @seller.reload.superfrete_webhook_key
      assert_equal "b" * 64, @seller.superfrete_webhook_secret
    end

    test "a failure deleting the old webhook does not undo the new one" do
      Webhook.new(@seller, client: @client).register
      @client.create_webhook_result = { id: "sf-webhook-2", secret: "b" * 64 }
      @client.delete_webhook_result = Client::Rejected.new("não encontrado")

      assert Webhook.new(@seller, client: @client).register
      assert_equal "sf-webhook-2", @seller.reload.superfrete_webhook_id
    end

    test "does nothing while labels are off or the connection is not ready" do
      Rails.configuration.x.shipping.labels_enabled = false
      assert_not Webhook.new(@seller, client: @client).register
      Rails.configuration.x.shipping.labels_enabled = true

      @seller.mark_superfrete_revoked!
      assert_not Webhook.new(@seller, client: @client).register
      assert_empty @client.calls
    ensure
      Rails.configuration.x.shipping.labels_enabled = true
    end

    test "disconnecting clears the webhook columns" do
      Webhook.new(@seller, client: @client).register

      @seller.reload.disconnect_superfrete!

      assert_nil @seller.reload.superfrete_webhook_key
      assert_nil @seller.superfrete_webhook_secret_ciphertext
      assert_nil @seller.superfrete_webhook_id
    end
  end
end
