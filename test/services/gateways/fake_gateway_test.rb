require "test_helper"

module Gateways
  class FakeGatewayTest < ActiveSupport::TestCase
    setup { @gateway = FakeGateway.new }

    test "authorize returns an intent with an external_id" do
      intent = @gateway.authorize(order: orders(:one))
      assert intent.external_id.present?
    end

    test "verify_webhook accepts the correct secret" do
      assert @gateway.verify_webhook(FakeGateway::WEBHOOK_SECRET)
    end

    test "verify_webhook rejects an incorrect secret" do
      assert_not @gateway.verify_webhook("wrong-secret")
    end

    test "verify_webhook rejects a blank secret" do
      assert_not @gateway.verify_webhook(nil)
    end
  end
end
