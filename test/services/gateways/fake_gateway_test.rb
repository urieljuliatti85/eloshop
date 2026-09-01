require "test_helper"

module Gateways
  class FakeGatewayTest < ActiveSupport::TestCase
    setup { @gateway = FakeGateway.new }

    test "authorize returns an intent with an external_id" do
      intent = @gateway.authorize(order: orders(:one), idempotency_key: SecureRandom.uuid, application_fee_cents: 0)

      assert intent.external_id.present?
      assert_not intent.pix?, "o gateway simulado não emite PIX"
    end

    test "verify_webhook accepts the correct secret" do
      assert @gateway.verify_webhook(request_with(secret: FakeGateway::WEBHOOK_SECRET))
    end

    test "verify_webhook rejects an incorrect secret" do
      assert_not @gateway.verify_webhook(request_with(secret: "wrong-secret"))
    end

    test "verify_webhook rejects a blank secret" do
      assert_not @gateway.verify_webhook(request_with(secret: nil))
    end

    # No gateway simulado é a própria requisição que carrega o desfecho, porque
    # quem a dispara são os botões da tela de pagamento. Um gateway real nunca
    # confia nisso — ver Gateways::MercadoPago#webhook_event.
    test "webhook_event reads the outcome from the request" do
      request = request_with(event_id: "evt-1", external_id: "fake_abc", status: "approved")

      assert_equal({ event_id: "evt-1", external_id: "fake_abc", status: "approved" },
                   @gateway.webhook_event(request))
    end

    private

    def request_with(**params)
      ActionDispatch::TestRequest.create.tap do |request|
        request.params.merge!(params.stringify_keys)
      end
    end
  end
end
