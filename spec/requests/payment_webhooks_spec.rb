# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payment webhooks", type: :request do
  let(:customer) { Customer.create!(name: "Cliente webhook", email: "webhook@example.com", password: "password123") }
  let(:order) do
    Order.create!(
      customer: customer,
      status: "pending",
      subtotal_cents: 1000,
      shipping_cents: 500,
      total_cents: 1500,
      shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
      idempotency_key: SecureRandom.uuid
    )
  end
  let(:payment) { Payment.create!(order: order, gateway: "fake", external_id: "pay-#{SecureRandom.hex(4)}", amount_cents: 1500, status: "pending") }

  describe "POST /fake_gateway_webhook" do
    it "rejects bad secrets without creating a PaymentEvent" do
      expect do
        post fake_gateway_webhook_path, params: {
          event_id: SecureRandom.hex(10),
          external_id: payment.external_id,
          status: "approved",
          secret: "wrong-secret"
        }
      end.not_to change(PaymentEvent, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it "approves a valid webhook and confirms the order" do
      post fake_gateway_webhook_path, params: {
        event_id: SecureRandom.hex(10),
        external_id: payment.external_id,
        status: "approved",
        secret: Gateways::FakeGateway::WEBHOOK_SECRET
      }

      expect(response).to have_http_status(:redirect)
      expect(payment.reload).to be_paid
      expect(order.reload).to be_confirmed
    end

    it "ignores duplicate event ids" do
      params = {
        event_id: SecureRandom.hex(10),
        external_id: payment.external_id,
        status: "approved",
        secret: Gateways::FakeGateway::WEBHOOK_SECRET
      }

      post fake_gateway_webhook_path, params: params

      expect do
        post fake_gateway_webhook_path, params: params
      end.not_to change(PaymentEvent, :count)
    end

    it "returns unprocessable for unknown external ids" do
      post fake_gateway_webhook_path, params: {
        event_id: SecureRandom.hex(10),
        external_id: "unknown",
        status: "approved",
        secret: Gateways::FakeGateway::WEBHOOK_SECRET
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
