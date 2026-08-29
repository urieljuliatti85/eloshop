require "test_helper"

class PaymentWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "rejects a webhook with an invalid secret and does not create a PaymentEvent" do
    assert_no_difference("PaymentEvent.count") do
      post fake_gateway_webhook_path, params: {
        event_id: SecureRandom.hex(10),
        external_id: payments(:one).external_id,
        status: "approved",
        secret: "wrong-secret"
      }
    end

    assert_response :unauthorized
  end

  test "processes an approved webhook with a valid secret and confirms the order" do
    post fake_gateway_webhook_path, params: {
      event_id: SecureRandom.hex(10),
      external_id: payments(:one).external_id,
      status: "approved",
      secret: Gateways::FakeGateway::WEBHOOK_SECRET
    }

    assert_redirected_to new_order_payment_path(orders(:one))
    assert payments(:one).reload.paid?
    assert orders(:one).reload.confirmed?
  end

  test "resubmitting the same event_id does not duplicate the effect" do
    event_id = SecureRandom.hex(10)
    params = { event_id: event_id, external_id: payments(:one).external_id, status: "approved", secret: Gateways::FakeGateway::WEBHOOK_SECRET }

    post fake_gateway_webhook_path, params: params

    assert_no_difference("PaymentEvent.count") do
      post fake_gateway_webhook_path, params: params
    end

    assert_response :redirect
  end

  test "returns unprocessable_entity for an unknown external_id" do
    post fake_gateway_webhook_path, params: {
      event_id: SecureRandom.hex(10),
      external_id: "unknown",
      status: "approved",
      secret: Gateways::FakeGateway::WEBHOOK_SECRET
    }

    assert_response :unprocessable_entity
  end

  # O ambiente de teste desativa a proteção CSRF por padrão
  # (config.action_controller.allow_forgery_protection = false), então esse
  # teste liga a proteção de propósito — um gateway de verdade nunca teria um
  # token CSRF, e sem o skip_forgery_protection este endpoint quebraria em
  # desenvolvimento/produção mesmo passando os outros testes.
  test "accepts a webhook request without a CSRF token even with forgery protection enabled" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post fake_gateway_webhook_path, params: {
      event_id: SecureRandom.hex(10),
      external_id: payments(:one).external_id,
      status: "approved",
      secret: Gateways::FakeGateway::WEBHOOK_SECRET
    }

    assert_response :redirect
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
