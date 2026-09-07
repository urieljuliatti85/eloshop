# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin orders", type: :request do
  let(:user) { User.create!(email_address: "orders-admin@example.com", password: "password", password_confirmation: "password") }
  let(:customer) { Customer.create!(name: "Cliente order", email: "order@example.com", password: "password123") }
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

  describe "GET /admin/orders" do
    it "redirects unauthenticated users" do
      get admin_orders_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated admins to list orders" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/orders/:id" do
    it "allows admins to view any order" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/orders/:id/refund" do
    it "allows the platform admin to refund an approved payment" do
      seller = Seller.create!(name: "Ateliê Refund", status: :approved, approved_at: Time.current)
      seller_order = order.seller_orders.create!(
        seller: seller,
        status: :confirmed,
        subtotal_cents: 1000,
        shipping_cents: 500,
        total_cents: 1500,
        platform_fee_cents: 150,
        seller_amount_cents: 1350
      )
      payment = order.payments.create!(gateway: "fake", external_id: "fake-refund", status: :paid, amount_cents: 1500, application_fee_cents: 150)
      order.update!(status: :confirmed)
      post session_path, params: { email_address: user.email_address, password: "password" }

      post refund_admin_order_path(order), params: { amount: "5,00", idempotency_key: "admin-refund" }

      expect(response).to redirect_to(admin_order_path(order))
      expect(payment.reload.refunded_amount_cents).to eq(500)
      expect(payment.application_fee_refunded_cents).to eq(50)
      expect(seller_order.reload.refunded_amount_cents).to eq(500)
    end

    it "does not allow an unauthenticated refund" do
      post refund_admin_order_path(order), params: { amount: "5,00", idempotency_key: "anonymous-refund" }

      expect(response).to redirect_to(new_session_path)
      expect(PaymentRefund.find_by(idempotency_key: "anonymous-refund")).to be_nil
    end
  end

  describe "POST /admin/orders/:id/cancel" do
    let(:seller) { Seller.create!(name: "Ateliê Cancel", status: :approved, approved_at: Time.current) }
    let(:product) { Product.create!(seller: seller, name: "Produto", sku: "SKU-CANCEL-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active") }
    let(:seller_order) do
      order.seller_orders.create!(
        seller: seller, status: :pending, subtotal_cents: 1000, shipping_cents: 500,
        total_cents: 1500, platform_fee_cents: 150, seller_amount_cents: 1350
      )
    end
    let!(:order_item) do
      OrderItem.create!(order: order, seller_order: seller_order, product: product,
        product_name: product.name, sku: product.sku, unit_price_cents: 1000, quantity: 1)
    end

    it "cancels a pending order and restores stock" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      post cancel_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
      expect(order.reload.cancelled?).to be(true)
      expect(product.reload.stock_quantity).to eq(6)
    end

    it "refuses to cancel an order with an authorized payment" do
      order.payments.create!(gateway: "fake", external_id: "fake-cancel", status: :paid, amount_cents: 1500, application_fee_cents: 150)
      post session_path, params: { email_address: user.email_address, password: "password" }

      post cancel_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
      expect(order.reload.pending?).to be(true)
    end

    it "does not allow an unauthenticated cancel" do
      post cancel_admin_order_path(order)

      expect(response).to redirect_to(new_session_path)
      expect(order.reload.pending?).to be(true)
    end
  end
end
