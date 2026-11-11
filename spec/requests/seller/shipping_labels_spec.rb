require "rails_helper"

# Etiqueta da SuperFrete pelo painel (ADR 005, "Etapa 2 e 3"). A SuperFrete é
# simulada: o comportamento real foi verificado no sandbox (docs/shipping.md).
RSpec.describe "Seller shipping labels", type: :request do
  include ActiveJob::TestHelper

  let(:seller) do
    Seller.create!(name: "Ateliê Etiqueta", owner_full_name: "Maria da Silva", cpf: "12444457463", status: :approved, approved_at: Time.current,
      origin_zip_code: "01001-000", origin_street: "Praça da Sé", origin_number: "100", origin_neighborhood: "Sé", origin_city: "São Paulo", origin_state: "SP")
  end
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Etiqueta", owner_full_name: "João Souza", cpf: "12555569197", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "etiqueta-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:customer) { Customer.create!(name: "Cliente", email: "label-customer-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:client) { instance_double(ShippingLabels::Client) }
  let(:pac) do
    ShippingLabels::Client::Option.new(service_code: 1, service_name: "PAC", carrier: "Correios", price_cents: 2_351, delivery_days: 3,
      height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500)
  end

  before do
    connect_superfrete!(seller, email: user.email_address)
    sign_in_as(user)
    allow(ShippingLabels).to receive(:client_for).and_return(client)
  end

  it "quotes the package and shows the price, the final box and the difference the atelier pays" do
    order = paid_order_for(seller)
    allow(client).to receive(:quote).and_return([ pac ])

    get new_seller_order_shipping_label_path(order, height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("PAC", "R$ 23,51", "10 × 16 × 24 cm", "a diferença de R$ 13,51 fica por sua conta")
    expect(client).to have_received(:quote).with(origin_zip_code: "01001000", destination_zip_code: "20040020",
      height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500)
  end

  it "requests the label and leaves the purchase to the job" do
    order = paid_order_for(seller)
    allow(client).to receive(:quote).and_return([ pac ])

    expect do
      post seller_order_shipping_label_path(order), params: { service_code: 1, height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500 }
    end.to have_enqueued_job(PurchaseShippingLabelJob)

    expect(response).to redirect_to(seller_order_path(order))
    label = order.shipment.shipping_labels.sole
    expect(label).to be_draft
    expect(label.quoted_price_cents).to eq(2_351)
  end

  it "explains why it cannot buy when the SuperFrete account is someone else's" do
    seller.update!(superfrete_account_email: "outra-pessoa@example.com")
    order = paid_order_for(seller)

    get new_seller_order_shipping_label_path(order)

    expect(Nokogiri::HTML(response.body).at_css("[data-label-blocker]").text).to include("mesmo e-mail")

    post seller_order_shipping_label_path(order), params: { service_code: 1, height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500 }
    expect(flash[:alert]).to include("mesmo e-mail")
    expect(ShippingLabel.count).to eq(0)
  end

  it "does not reach another atelier's order on any action" do
    order = paid_order_for(other_seller)
    label = order.shipment.shipping_labels.create!(status: :purchased, provider_order_id: "sf-other", service_code: 1, service_name: "PAC",
      quoted_price_cents: 2_351, height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500, sandbox: false, superfrete_account_id: "x")

    get new_seller_order_shipping_label_path(order)
    expect(response).to have_http_status(:not_found)
    post seller_order_shipping_label_path(order), params: { service_code: 1 }
    expect(response).to have_http_status(:not_found)
    get print_seller_order_shipping_label_path(order)
    expect(response).to have_http_status(:not_found)
    delete seller_order_shipping_label_path(order)
    expect(response).to have_http_status(:not_found)
    expect(label.reload).to be_purchased
  end

  it "prints by asking SuperFrete for a fresh https link" do
    order = paid_order_for(seller)
    create_label(order, status: :purchased)
    allow(client).to receive(:order_info).and_return(info(print_url: "https://sandbox.superfrete.com/etiqueta.pdf"))

    get print_seller_order_shipping_label_path(order)

    expect(response).to redirect_to("https://sandbox.superfrete.com/etiqueta.pdf")
  end

  it "does not redirect to a print link that is not https" do
    order = paid_order_for(seller)
    create_label(order, status: :purchased)
    allow(client).to receive(:order_info).and_return(info(print_url: "javascript:alert(1)"))

    get print_seller_order_shipping_label_path(order)

    expect(response).to redirect_to(seller_order_path(order))
  end

  it "cancels the label only when the atelier clicks" do
    order = paid_order_for(seller)
    label = create_label(order, status: :purchased)
    allow(client).to receive(:cancel).and_return(true)

    delete seller_order_shipping_label_path(order)

    expect(response).to redirect_to(seller_order_path(order))
    expect(label.reload).to be_cancelled
  end

  it "shows the purchased label on the order page and pre-fills the tracking code" do
    order = paid_order_for(seller)
    create_label(order, status: :purchased, tracking_code: "AA123456789BR")

    get seller_order_path(order)

    page = Nokogiri::HTML(response.body)
    expect(page.at_css("[data-shipping-label-card]").text).to include("PAC", "AA123456789BR", "Imprimir etiqueta")
    expect(page.at_css("input[name='tracking_code']")["value"]).to eq("AA123456789BR")
  end

  it "explains a posting that could not move the order, without offering to cancel the label" do
    order = paid_order_for(seller)
    create_label(order, status: :purchased, purchased_at: 1.day.ago, posted_at: Time.current, tracking_code: "AA123456789BR")

    get seller_order_path(order)

    card = Nokogiri::HTML(response.body).at_css("[data-shipping-label-card]")
    expect(card.at_css("[data-label-posted]").text).to include("informou a postagem")
    expect(card.at_css("form[action='#{seller_order_shipping_label_path(order)}']")).to be_nil
  end

  it "hides the card when labels are switched off" do
    order = paid_order_for(seller)
    Rails.configuration.x.shipping.labels_enabled = false

    get seller_order_path(order)

    expect(response.body).not_to include("data-shipping-label-card")
  ensure
    Rails.configuration.x.shipping.labels_enabled = true
  end

  it "checks a payment that was not confirmed again, without paying again" do
    order = paid_order_for(seller)
    label = create_label(order, status: :purchasing)

    expect do
      post reconcile_seller_order_shipping_label_path(order)
    end.to have_enqueued_job(PurchaseShippingLabelJob).with(label)
  end

  # Regressões do QA de 2026-11-05.
  describe "ways out the atelier always has" do
    it "offers checking again and cancelling a label stuck before payment (job died midway)" do
      order = paid_order_for(seller)
      label = create_label(order, status: :draft, provider_order_id: nil)

      get seller_order_path(order)
      buttons = Nokogiri::HTML(response.body).css("[data-shipping-label-card] button").map { |button| button.text.squish }
      expect(buttons).to include("Conferir de novo", "Cancelar etiqueta")

      delete seller_order_shipping_label_path(order)
      expect(label.reload).to be_cancelled
    end

    it "keeps the purchased label cancellable while a full refund is in progress, without the print button" do
      order = paid_order_for(seller)
      create_label(order, status: :purchased)
      payment = order.payments.create!(gateway: "fake", external_id: "fake-#{SecureRandom.hex(3)}", status: "paid", amount_cents: order.total_cents)
      payment.payment_refunds.create!(idempotency_key: SecureRandom.hex(6), amount_cents: payment.amount_cents, application_fee_amount_cents: 0)

      get seller_order_path(order)

      card = Nokogiri::HTML(response.body).at_css("[data-shipping-label-card]")
      expect(card.at_css("[data-label-refunding]")).to be_present
      expect(card.text).to include("Cancelar etiqueta")
      expect(card.text).not_to include("Imprimir etiqueta")
    end

    it "keeps the purchased label cancellable after the order was refunded" do
      order = paid_order_for(seller)
      label = create_label(order, status: :purchased)
      order.seller_order.update!(status: :refunded)
      allow(client).to receive(:cancel).and_return(true)

      get seller_order_path(order)
      expect(Nokogiri::HTML(response.body).at_css("[data-shipping-label-card] [data-label-refunding]")).to be_present

      delete seller_order_shipping_label_path(order)
      expect(label.reload).to be_cancelled
    end
  end

  describe "package measures" do
    it "does not quote, and explains, when the measures are not positive whole numbers" do
      order = paid_order_for(seller)
      allow(client).to receive(:quote)

      get new_seller_order_shipping_label_path(order, height_cm: "abc", width_cm: "-5", length_cm: "1e9", weight_grams: "")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("números inteiros maiores que zero")
      expect(client).not_to have_received(:quote)
    end

    it "says the order already has a label instead of offering the form again" do
      order = paid_order_for(seller)
      create_label(order, status: :purchased)
      allow(client).to receive(:quote)

      get new_seller_order_shipping_label_path(order, height_cm: 10, width_cm: 15, length_cm: 20, weight_grams: 500)

      expect(Nokogiri::HTML(response.body).at_css("[data-label-blocker]").text).to include("Já existe uma etiqueta")
      expect(client).not_to have_received(:quote)
    end
  end

  private

  def info(print_url:)
    ShippingLabels::Client::OrderInfo.new(id: "sf-1", status: "released", tracking: nil, price_cents: 2_351, service_code: 1, print_url: print_url)
  end

  def create_label(order, status:, **attributes)
    order.shipment.shipping_labels.create!({ status: status, provider_order_id: "sf-#{SecureRandom.hex(3)}", service_code: 1, service_name: "PAC",
      quoted_price_cents: 2_351, height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500,
      sandbox: seller.superfrete_sandbox?, superfrete_account_id: seller.superfrete_account_id }.merge(attributes))
  end

  def paid_order_for(order_seller)
    product = Product.create!(seller: order_seller, name: "Caneca", sku: "LABEL-#{SecureRandom.hex(3)}", price_cents: 5_000, stock_quantity: 2,
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
