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

    it "paginates orders" do
      per_page = Paginatable::DEFAULT_PER_PAGE
      (per_page * 2 - Order.count).times do |i|
        Order.create!(
          customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 500, total_cents: 1500,
          shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
          idempotency_key: "pag-#{i}-#{SecureRandom.hex(4)}"
        )
      end
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 1 de 2")
    end

    it "sorts by total ascending and descending" do
      cheap = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 500, shipping_cents: 0, total_cents: 500,
        shipping_address_snapshot: { street: "Rua Teste", number: "1" }, idempotency_key: SecureRandom.uuid
      )
      expensive = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 90_000, shipping_cents: 0, total_cents: 90_000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(sort: "total", direction: "asc")
      expect(response.body.index("##{cheap.id}")).to be < response.body.index("##{expensive.id}")

      get admin_orders_path(sort: "total", direction: "desc")
      expect(response.body.index("##{expensive.id}")).to be < response.body.index("##{cheap.id}")
    end

    it "sorts by customer name" do
      customer_a = Customer.create!(name: "Ana Ordenação", email: "ana-order-sort@example.com", password: "password123")
      customer_z = Customer.create!(name: "Zeca Ordenação", email: "zeca-order-sort@example.com", password: "password123")
      order_a = Order.create!(
        customer: customer_a, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "1" }, idempotency_key: SecureRandom.uuid
      )
      order_z = Order.create!(
        customer: customer_z, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(sort: "customer", direction: "asc")

      expect(response.body.index("##{order_a.id}")).to be < response.body.index("##{order_z.id}")
    end

    it "filters by order id" do
      other_order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(order_id: order.id)

      expect(response.body).to include("##{order.id}")
      expect(response.body).not_to include("##{other_order.id}")
    end

    it "filters by customer name or email" do
      other_customer = Customer.create!(name: "Outro Cliente Filtro", email: "outro-filtro@example.com", password: "password123")
      order
      other_order = Order.create!(
        customer: other_customer, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(customer: customer.name)

      expect(response.body).to include("##{order.id}")
      expect(response.body).not_to include("##{other_order.id}")
    end

    it "filters by seller" do
      seller = Seller.create!(name: "Ateliê Filtro Pedido", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)
      other_seller = Seller.create!(name: "Outro Ateliê Filtro Pedido", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)
      order.seller_orders.create!(seller: seller, status: :pending, subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000, platform_fee_cents: 150, seller_amount_cents: 850)
      other_order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      other_order.seller_orders.create!(seller: other_seller, status: :pending, subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000, platform_fee_cents: 150, seller_amount_cents: 850)
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(seller_id: seller.id)

      expect(response.body).to include("##{order.id}")
      expect(response.body).not_to include("##{other_order.id}")
    end

    it "filters by payment status" do
      paid_order = order
      paid_order.payments.create!(gateway: "fake", status: "paid", amount_cents: 1500, application_fee_cents: 0, idempotency_key: SecureRandom.uuid, external_id: "ext-#{SecureRandom.hex(4)}")
      not_started_order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(payment_status: "paid")
      expect(response.body).to include("##{paid_order.id}")
      expect(response.body).not_to include("##{not_started_order.id}")

      get admin_orders_path(payment_status: "not_started")
      expect(response.body).to include("##{not_started_order.id}")
      expect(response.body).not_to include("##{paid_order.id}")
    end

    it "filters by date" do
      travel_to Time.zone.local(2026, 3, 10, 12, 0, 0) do
        order
      end
      other_order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 0, total_cents: 1000,
        shipping_address_snapshot: { street: "Rua Teste", number: "2" }, idempotency_key: SecureRandom.uuid, created_at: Time.zone.local(2026, 3, 20, 12, 0, 0)
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(date: "10/03/2026")

      expect(response.body).to include("##{order.id}")
      expect(response.body).not_to include("##{other_order.id}")
    end

    it "ignores an invalid date filter instead of raising" do
      order
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path(date: "not-a-date")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("##{order.id}")
    end

    it "shows a dash for the atelier columns when the order has no seller_order yet" do
      order
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("—")
    end

    it "shows the atelier name and its owner's email for orders with a seller_order" do
      seller = Seller.create!(name: "Ateliê Listagem", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)
      seller_user = User.create!(email_address: "atelie-listagem@example.com", password: "password123", role: :seller, seller: seller)
      order.seller_orders.create!(
        seller: seller, status: :pending, subtotal_cents: 1000, shipping_cents: 500,
        total_cents: 1500, platform_fee_cents: 150, seller_amount_cents: 1350
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response.body).to include(seller.name)
      expect(response.body).to include(seller_user.email_address)
    end

    it "shows the shipment status for orders that have a shipment" do
      seller = Seller.create!(name: "Ateliê Entrega Listagem", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)
      seller_order = order.seller_orders.create!(
        seller: seller, status: :confirmed, subtotal_cents: 1000, shipping_cents: 500,
        total_cents: 1500, platform_fee_cents: 150, seller_amount_cents: 1350
      )
      order.update!(status: :confirmed)
      seller_order.create_shipment!(carrier: "Correios", service: "PAC", shipping_cents: 500, estimated_days: 5)
      seller_order.shipment.mark_shipped!
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_orders_path

      expect(response.body).to include("Enviado")
    end
  end

  describe "GET /admin/orders/:id" do
    it "allows admins to view any order" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
    end

    it "shows the technical timeline with errors when present" do
      OrderEvent.create!(order: order, kind: :order_created, status: "pending")
      OrderEvent.create!(
        order: order, kind: :payment_authorize_failed, status: "failed",
        error_class: "Net::ReadTimeout", error_message: "gateway timeout"
      )
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pedido criado")
      expect(response.body).to include("Falha ao autorizar pagamento")
      expect(response.body).to include("Net::ReadTimeout")
      expect(response.body).to include("gateway timeout")
    end

    it "shows the shipment status badge when a shipment exists" do
      seller = Seller.create!(name: "Ateliê Entrega Show", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)
      seller_order = order.seller_orders.create!(
        seller: seller, status: :confirmed, subtotal_cents: 1000, shipping_cents: 500,
        total_cents: 1500, platform_fee_cents: 150, seller_amount_cents: 1350
      )
      order.update!(status: :confirmed)
      seller_order.create_shipment!(carrier: "Correios", service: "PAC", shipping_cents: 500, estimated_days: 5)
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pendente")
    end
  end

  describe "POST /admin/orders/:id/refund" do
    it "allows the platform admin to refund an approved payment" do
      seller = Seller.create!(name: "Ateliê Refund", owner_full_name: "Proprietário Teste", cpf: "10444446818", status: :approved, approved_at: Time.current)
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

      notification = seller.notifications.order_refunded.last
      expect(notification).to be_present
      expect(notification.title).to eq("Reembolso parcial")
    end

    it "does not allow an unauthenticated refund" do
      post refund_admin_order_path(order), params: { amount: "5,00", idempotency_key: "anonymous-refund" }

      expect(response).to redirect_to(new_session_path)
      expect(PaymentRefund.find_by(idempotency_key: "anonymous-refund")).to be_nil
    end
  end

  describe "POST /admin/orders/:id/cancel" do
    let(:seller) { Seller.create!(name: "Ateliê Cancel", owner_full_name: "Proprietário Teste", cpf: "10555558541", status: :approved, approved_at: Time.current) }
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

      notification = seller.notifications.order_cancelled.last
      expect(notification).to be_present
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
