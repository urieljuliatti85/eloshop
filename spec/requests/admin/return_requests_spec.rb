# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin return requests", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { User.create!(email_address: "rr-admin-#{SecureRandom.hex(3)}@example.com", password: "password", password_confirmation: "password") }
  let(:customer) { Customer.create!(name: "Cliente fila", email: "fila-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:product) { Product.create!(seller: approved_seller, name: "Peça fila", sku: "RRA-#{SecureRandom.hex(3)}", price_cents: 8_000, stock_quantity: 2, status: :active) }
  let(:seller_order) { paid_seller_order }
  let(:return_request) { ReturnRequests::Open.new(seller_order: seller_order, customer: customer, kind: :withdrawal).call.return_request }

  def sign_in_admin
    post session_path, params: { email_address: admin.email_address, password: "password" }
  end

  it "keeps everyone but admins out" do
    get admin_return_requests_path
    expect(response).to redirect_to(new_session_path)

    sign_in_as(approved_seller.users.first, password: "password123")
    get admin_return_request_path(return_request)
    expect(response).not_to have_http_status(:ok)

    patch admin_return_request_path(return_request), params: { return_request_update: { status: "closed" } }
    expect(return_request.reload).to be_received
  end

  it "lists open requests by deadline, with the overdue ones flagged" do
    return_request.update_columns(respond_by: Date.current - 1)
    sign_in_admin

    get admin_return_requests_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(return_request.protocol, "Atrasada")
  end

  it "answers the buyer, changes the status and notifies by e-mail" do
    sign_in_admin

    expect {
      patch admin_return_request_path(return_request),
        params: { return_request_update: { body: "Vamos reembolsar o valor integral.", status: "in_progress" } }
    }.to have_enqueued_mail(ReturnRequestMailer, :updated)

    expect(response).to redirect_to(admin_return_request_path(return_request))
    expect(return_request.reload).to be_in_progress
    expect(return_request.updates.chronological.last.author).to eq(admin)
    expect(Notification.where(recipient: customer, kind: "return_request_updated")).to exist
  end

  it "keeps the answer saved when the e-mail cannot be queued" do
    allow(ReturnRequestMailer).to receive(:updated).and_raise(ActiveRecord::ConnectionNotEstablished, "fila fora do ar")
    sign_in_admin

    patch admin_return_request_path(return_request), params: { return_request_update: { body: "Resposta.", status: "in_progress" } }

    expect(response).to redirect_to(admin_return_request_path(return_request))
    expect(return_request.reload).to be_in_progress
    expect(Notification.where(recipient: customer, kind: "return_request_updated")).to exist
  end

  it "tells the atelier when a withdrawal ends, because shipping is unlocked" do
    sign_in_admin

    patch admin_return_request_path(return_request), params: { return_request_update: { status: "closed", body: "O comprador desistiu da desistência." } }

    expect(Notification.where(recipient: seller_order.seller, kind: "return_request_updated")).to exist
  end

  it "refuses an invalid transition without changing anything" do
    return_request.record_update!(author: admin, new_status: "resolved")
    sign_in_admin

    patch admin_return_request_path(return_request), params: { return_request_update: { status: "in_progress" } }

    expect(flash[:alert]).to include("Não é possível")
    expect(return_request.reload).to be_resolved
  end

  it "never renders the buyer's text as HTML" do
    payload = %(<script>alert("x")</script><img src=x onerror="alert(1)">)
    request = ReturnRequests::Open.new(seller_order: seller_order, customer: customer, kind: :product_issue, description: payload).call.return_request
    sign_in_admin

    get admin_return_request_path(request)

    expect(response.body).not_to include("<script>alert", "onerror=")
  end

  it "shows the open request on the order page, pointing to it" do
    return_request
    sign_in_admin

    get admin_order_path(seller_order.order)

    expect(response.body).to include("Solicitação aberta", admin_return_request_path(return_request))
  end

  private

  def paid_seller_order
    order = Order.create!(
      customer: customer, status: :confirmed,
      subtotal_cents: product.price_cents, shipping_cents: 1_000, discount_cents: 0, total_cents: product.price_cents + 1_000,
      shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" }, idempotency_key: SecureRandom.hex(12)
    )
    platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: order.subtotal_cents, discount_cents: 0)
    order.seller_orders.create!(
      seller: product.seller, status: :confirmed,
      subtotal_cents: order.subtotal_cents, discount_cents: 0, shipping_cents: order.shipping_cents,
      total_cents: order.total_cents, platform_fee_cents: platform_fee, seller_amount_cents: order.total_cents - platform_fee
    ).tap do |created|
      order.order_items.create!(seller_order: created, product: product, product_name: product.name,
        sku: product.sku, unit_price_cents: product.price_cents, quantity: 1)
    end
  end
end
