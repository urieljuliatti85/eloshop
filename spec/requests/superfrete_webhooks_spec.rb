require "rails_helper"

# Webhook de rastreio da SuperFrete (ADR 005). Formato confirmado pela
# SuperFrete em 2026-11-11: X-ME-Signature é o HMAC-SHA256 do corpo bruto com
# o `secret_token` do webhook do ateliê, em hexadecimal, sem prefixo.
RSpec.describe "SuperFrete tracking webhook", type: :request do
  include ActiveJob::TestHelper

  let(:secret) { "c" * 64 }
  let(:seller) do
    Seller.create!(name: "Ateliê Rastreio", owner_full_name: "Maria da Silva", cpf: "12444457463", status: :approved, approved_at: Time.current)
  end
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Rastreio", owner_full_name: "João Souza", cpf: "12555569197", status: :approved, approved_at: Time.current) }
  let(:customer) { Customer.create!(name: "Cliente", email: "tracking-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:order) { paid_order_for(seller) }
  let(:label) do
    order.shipment.shipping_labels.create!(status: :purchased, provider_order_id: "sf-order-9", service_code: 1, service_name: "PAC",
      quoted_price_cents: 2_351, height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500, purchased_at: Time.current,
      sandbox: seller.superfrete_sandbox?, superfrete_account_id: seller.superfrete_account_id)
  end

  before do
    connect_superfrete!(seller)
    seller.store_superfrete_webhook!(id: "wh-1", key: "seller-key", secret: secret)
    connect_superfrete!(other_seller)
    other_seller.store_superfrete_webhook!(id: "wh-2", key: "other-key", secret: "d" * 64)
    label
  end

  def body_for(event, status, id: "sf-order-9")
    { event: event, data: { id: id, order_id: id, status: status, tracking: "AA123456789BR" } }.to_json
  end

  def deliver(body, key: "seller-key", signature: OpenSSL::HMAC.hexdigest("SHA256", secret, body))
    post superfrete_webhook_path(key), params: body, headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => "SuperFrete Webhooks/1.0", "X-ME-Signature" => signature }
  end

  it "accepts a signed notification, records it and moves the shipment in the job" do
    perform_enqueued_jobs(only: ProcessShippingLabelEventJob) do
      deliver(body_for("order.posted", "posted"))
    end

    expect(response).to have_http_status(:ok)
    expect(ShippingLabelEvent.sole).to have_attributes(event: "order.posted", status: "posted", processed_at: be_present)
    expect(order.shipment.reload).to be_shipped
    expect(order.shipment.tracking_code).to eq("AA123456789BR")
  end

  it "takes the same notification twice as one" do
    body = body_for("order.posted", "posted")

    expect { 2.times { deliver(body) } }.to have_enqueued_job(ProcessShippingLabelEventJob).exactly(:once)
    expect(response).to have_http_status(:ok)
    expect(ShippingLabelEvent.count).to eq(1)
  end

  it "rejects a wrong or missing signature without recording anything" do
    body = body_for("order.posted", "posted")

    deliver(body, signature: OpenSSL::HMAC.hexdigest("SHA256", "e" * 64, body))
    expect(response).to have_http_status(:unauthorized)
    deliver(body, signature: "")
    expect(response).to have_http_status(:unauthorized)
    deliver(body, signature: Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, body)))
    expect(response).to have_http_status(:unauthorized)

    expect(ShippingLabelEvent.count).to eq(0)
  end

  it "answers an unknown key exactly like a bad signature" do
    deliver(body_for("order.posted", "posted"), key: "nope")

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not let another seller's webhook reach this seller's label" do
    body = body_for("order.delivered", "delivered")

    deliver(body, key: "other-key", signature: OpenSSL::HMAC.hexdigest("SHA256", "d" * 64, body))

    expect(response).to have_http_status(:ok)
    expect(ShippingLabelEvent.count).to eq(0)
    expect(order.shipment.reload).to be_pending
  end

  it "answers 200 to valid notifications it has nothing to do with" do
    deliver(body_for("order.posted", "posted", id: "unknown-order"))
    expect(response).to have_http_status(:ok)

    deliver("not json")
    expect(response).to have_http_status(:ok)
    expect(ShippingLabelEvent.count).to eq(0)
  end

  it "stops accepting notifications once the seller disconnects" do
    seller.disconnect_superfrete!

    deliver(body_for("order.posted", "posted"))

    expect(response).to have_http_status(:unauthorized)
  end

  def paid_order_for(order_seller)
    product = Product.create!(seller: order_seller, name: "Caneca", sku: "TRACK-#{SecureRandom.hex(3)}", price_cents: 5_000, stock_quantity: 2,
      height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500)
    order = Order.create!(customer: customer, status: :confirmed, subtotal_cents: 5_000, shipping_cents: 1_000, discount_cents: 0, total_cents: 6_000,
      shipping_address_snapshot: { "street" => "Rua do Ouvidor", "number" => "50", "neighborhood" => "Centro", "city" => "Rio de Janeiro", "state" => "RJ", "zip_code" => "20040-020" },
      recipient_name: "Ana Souza", recipient_cpf: "52998224725", idempotency_key: SecureRandom.hex(12))
    platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: 5_000, discount_cents: 0)
    seller_order = order.seller_orders.create!(seller: order_seller, status: :confirmed, subtotal_cents: 5_000, discount_cents: 0, shipping_cents: 1_000,
      total_cents: 6_000, platform_fee_cents: platform_fee, seller_amount_cents: 6_000 - platform_fee)
    order.order_items.create!(seller_order: seller_order, product: product, product_name: product.name, sku: product.sku, unit_price_cents: 5_000, quantity: 1)
    seller_order.create_shipment!(carrier: "Correios", service: "PAC", shipping_cents: 1_000, estimated_days: 5)
    order
  end
end
