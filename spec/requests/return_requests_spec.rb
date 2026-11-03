# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Return requests (desistência pelo site)", type: :request do
  include ActiveJob::TestHelper

  let(:customer) { Customer.create!(name: "Cliente desistência", email: "desiste-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:other_customer) { Customer.create!(name: "Outra cliente", email: "outra-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso solicitação", sku: "RR-#{SecureRandom.hex(3)}", price_cents: 10_000, stock_quantity: 3, status: :active) }
  let(:order) { paid_order_for(customer) }

  def sign_in_customer(as = customer)
    post customer_session_path, params: { email: as.email, password: "password123" }
  end

  describe "on the order page" do
    it "offers the request instead of cancelling a paid order" do
      sign_in_customer

      get order_path(order)

      expect(response.body).to include("Desistir da compra ou relatar um problema", new_order_return_request_path(order))
      expect(response.body).not_to include(cancel_order_path(order))
    end

    it "offers neither the request nor cancelling once the order is fully refunded" do
      order.update!(status: :refunded)
      order.seller_order.update!(status: :refunded)
      sign_in_customer

      get order_path(order)

      expect(response.body).not_to include(new_order_return_request_path(order))
      expect(response.body).not_to include(cancel_order_path(order))

      get new_order_return_request_path(order)
      expect(response).to redirect_to(order_path(order))
    end

    it "does not open the form for another customer's order" do
      sign_in_customer(other_customer)

      get new_order_return_request_path(order)

      expect(response).to have_http_status(:not_found)
    end

    it "after withdrawing, shows the open withdrawal instead of offering to withdraw again" do
      withdrawal = ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call.return_request
      sign_in_customer

      get order_path(order)

      expect(response.body).to include("Você pediu para desistir desta compra", withdrawal.protocol, order_return_request_path(order, withdrawal))
      expect(response.body).not_to include(new_order_return_request_path(order))

      get new_order_return_request_path(order)
      expect(response).to redirect_to(order_return_request_path(order, withdrawal))
    end

    it "offers only the kinds that are not open yet" do
      ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :delivery_issue).call
      sign_in_customer

      get order_path(order)
      expect(response.body).to include(new_order_return_request_path(order))

      get new_order_return_request_path(order)
      # Só o formulário: o sino do topo também mostra a notificação da solicitação aberta.
      choices = Nokogiri::HTML(response.body).css("form fieldset").text
      expect(choices).to include("Desistência da compra", "Problema com o produto")
      expect(choices).not_to include("Problema na entrega")
    end

    it "labels the order in the list while a request is open" do
      other_order = paid_order_for(customer)
      ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call
      ReturnRequests::Open.new(seller_order: other_order.seller_order, customer: customer, kind: :delivery_issue).call
      untouched = paid_order_for(customer)
      sign_in_customer

      get orders_path

      cards = Nokogiri::HTML(response.body).css("article")
      card_for = ->(o) { cards.find { |card| card.text.include?("Pedido ##{o.id}") }.text }
      expect(card_for.call(order)).to include("Desistência solicitada")
      expect(card_for.call(other_order)).to include("Solicitação aberta")
      expect(card_for.call(untouched)).not_to include("Desistência solicitada", "Solicitação aberta")
    end

    it "keeps cancelling an unpaid order" do
      order.update!(status: :pending)
      order.seller_order.update!(status: :pending)
      sign_in_customer

      get order_path(order)

      expect(response.body).to include(cancel_order_path(order))
      expect(response.body).not_to include(new_order_return_request_path(order))
    end
  end

  describe "POST /orders/:order_id/solicitacoes" do
    it "requires a signed-in customer" do
      post order_return_requests_path(order), params: { return_request: { kind: "withdrawal" } }

      expect(response).to redirect_to(new_customer_session_path)
      expect(ReturnRequest.count).to eq(0)
    end

    it "opens the request and shows the protocol right away" do
      sign_in_customer

      expect {
        post order_return_requests_path(order), params: { return_request: { kind: "withdrawal", description: "Não quero mais." } }
      }.to change(ReturnRequest, :count).by(1)
        .and have_enqueued_mail(ReturnRequestMailer, :opened)

      return_request = ReturnRequest.last
      expect(response).to redirect_to(order_return_request_path(order, return_request))
      expect(flash[:notice]).to include(return_request.protocol)

      follow_redirect!
      expect(response.body).to include(return_request.protocol, "Não quero mais.")
    end

    it "still shows the protocol when the e-mail cannot be queued" do
      allow(ReturnRequestMailer).to receive(:opened).and_raise(ActiveRecord::ConnectionNotEstablished, "fila fora do ar")
      sign_in_customer

      post order_return_requests_path(order), params: { return_request: { kind: "withdrawal" } }

      return_request = ReturnRequest.sole
      expect(response).to redirect_to(order_return_request_path(order, return_request))
      expect(flash[:notice]).to include(return_request.protocol)
    end

    it "works with sales closed: withdrawing is the buyer's right" do
      PlatformSetting.instance.update!(sales_opened_at: nil)
      sign_in_customer

      post order_return_requests_path(order), params: { return_request: { kind: "withdrawal" } }

      expect(response).to redirect_to(order_return_request_path(order, ReturnRequest.last))
    end

    it "cannot reach another customer's order by changing the id" do
      sign_in_customer(other_customer)

      post order_return_requests_path(order), params: { return_request: { kind: "withdrawal" } }

      expect(response).to have_http_status(:not_found)
      expect(ReturnRequest.count).to eq(0)
    end

    it "refuses an unpaid order and shows the form again" do
      order.seller_order.update!(status: :pending)
      sign_in_customer

      post order_return_requests_path(order), params: { return_request: { kind: "withdrawal" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ReturnRequest.count).to eq(0)
    end

    it "limits how many requests a customer opens in a row" do
      sign_in_customer
      kinds = %w[withdrawal product_issue delivery_issue withdrawal product_issue]
      kinds.each { |kind| post order_return_requests_path(order), params: { return_request: { kind: kind } } }

      post order_return_requests_path(order), params: { return_request: { kind: "delivery_issue" } }

      expect(response).to redirect_to(order_path(order))
      expect(flash[:alert]).to include("Muitas tentativas")
    end
  end

  describe "GET /orders/:order_id/solicitacoes/:id" do
    it "is visible only to the buyer who owns the order" do
      return_request = ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call.return_request
      sign_in_customer(other_customer)

      get order_return_request_path(order, return_request)

      expect(response).to have_http_status(:not_found)
    end

    it "shows the EloShop answer" do
      return_request = ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call.return_request
      return_request.record_update!(author: User.create!(email_address: "rr-admin-#{SecureRandom.hex(3)}@example.com", password: "password"),
        body: "Reembolso a caminho.", new_status: "in_progress")
      sign_in_customer

      get order_return_request_path(order, return_request)

      expect(response.body).to include("Reembolso a caminho.", "Em andamento")
    end
  end

  private

  def paid_order_for(order_customer)
    Order.create!(
      customer: order_customer,
      status: :confirmed,
      subtotal_cents: product.price_cents,
      shipping_cents: 1_000,
      discount_cents: 0,
      total_cents: product.price_cents + 1_000,
      shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" },
      idempotency_key: SecureRandom.hex(12)
    ).tap do |created|
      platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: created.subtotal_cents, discount_cents: 0)
      seller_order = created.seller_orders.create!(
        seller: product.seller, status: :confirmed,
        subtotal_cents: created.subtotal_cents, discount_cents: 0, shipping_cents: created.shipping_cents,
        total_cents: created.total_cents, platform_fee_cents: platform_fee, seller_amount_cents: created.total_cents - platform_fee
      )
      created.order_items.create!(seller_order: seller_order, product: product, product_name: product.name,
        sku: product.sku, unit_price_cents: product.price_cents, quantity: 1)
    end
  end
end
