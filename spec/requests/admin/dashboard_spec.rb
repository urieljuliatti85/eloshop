# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:user) { User.create!(email_address: "dashboard-admin@example.com", password: "password", password_confirmation: "password") }

  describe "GET /admin" do
    it "redirects unauthenticated users to login" do
      get admin_root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "shows pending orders, correct inventory values, and pending reviews" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      customer = Customer.create!(name: "Cliente dashboard", email: "dash@example.com", password: "password123")
      pending_product = Product.create!(seller: approved_seller, name: "Vaso baixo estoque", sku: "DASH-001", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)
      sold_out_product = Product.create!(seller: approved_seller, name: "Vaso esgotado", sku: "DASH-002", price_cents: 5_000, stock_quantity: 0, currency: "BRL", status: :sold_out)
      variant_product = Product.create!(seller: approved_seller, name: "Camiseta com variações", sku: "DASH-VAR-001", price_cents: 5_000, stock_quantity: 0, currency: "BRL", status: :active)
      low_stock_variant = variant_product.product_variants.create!(sku: "DASH-VAR-P", price_cents: 5_000, stock_quantity: 2, size: "P")
      sold_out_variant = variant_product.product_variants.create!(sku: "DASH-VAR-G", price_cents: 5_000, stock_quantity: 0, size: "G")
      order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1_000, shipping_cents: 500, total_cents: 1_500,
        shipping_address_snapshot: { street: "Rua", number: "1" }, idempotency_key: SecureRandom.uuid
      )
      review = customer.reviews.create!(product: pending_product, rating: 5, comment: "Ótimo", status: "pending")

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pending_product.name)
      expect(response.body).to include(sold_out_product.name)
      expect(response.body).to include("#{variant_product.name} — #{low_stock_variant.to_label}", "#{variant_product.name} — #{sold_out_variant.to_label}")
      expect(response.body).to include("2 un.")
      expect(response.body).to include("Itens esgotados")
      expect(response.body).to include(order.customer.name)
      expect(response.body).to include(review.customer.name)
      expect(response.body).to include("Área administrativa")
      expect(response.body).to include("Acompanhe o que precisa de atenção")
      expect(response.body).to include("admin-sidebar")
    end

    it "shows the total platform commission net of refunds, only for paid orders" do
      sign_in_as(user, password: "password")
      customer = Customer.create!(name: "Cliente comissão", email: "comissao@example.com", password: "password123")

      confirmed_order = create_order_with_seller_order!(customer: customer, status: "confirmed", subtotal_cents: 10_000, platform_fee_refunded_cents: 0)
      partially_refunded_order = create_order_with_seller_order!(customer: customer, status: "partially_refunded", subtotal_cents: 10_000, platform_fee_refunded_cents: 300)
      pending_order = create_order_with_seller_order!(customer: customer, status: "pending", subtotal_cents: 10_000, platform_fee_refunded_cents: 0)

      get admin_root_path

      expect(response.body).to include("Comissão total")
      # 1.500 (confirmado) + (1.500 - 300) (parcialmente reembolsado) = 2.700 = R$ 27,00 — pending_order não entra na soma.
      expect(response.body).to include(ApplicationController.helpers.format_price(2_700))
      expect([ confirmed_order, partially_refunded_order, pending_order ]).to all(be_persisted)
    end
  end

  def create_order_with_seller_order!(customer:, status:, subtotal_cents:, platform_fee_refunded_cents:)
    order = Order.create!(
      customer: customer, status: status, subtotal_cents: subtotal_cents, shipping_cents: 0, total_cents: subtotal_cents,
      shipping_address_snapshot: { street: "Rua", number: "1" }, idempotency_key: SecureRandom.uuid
    )
    platform_fee_cents = SellerOrder.platform_fee_cents_for(subtotal_cents: subtotal_cents, discount_cents: 0)
    SellerOrder.create!(
      order: order, seller: approved_seller, currency: "BRL",
      subtotal_cents: subtotal_cents, discount_cents: 0, shipping_cents: 0, total_cents: subtotal_cents,
      platform_fee_rate_bps: SellerOrder::PLATFORM_FEE_RATE_BPS, platform_fee_cents: platform_fee_cents,
      seller_amount_cents: subtotal_cents - platform_fee_cents,
      refunded_amount_cents: 0, platform_fee_refunded_cents: platform_fee_refunded_cents
    )
    order
  end
end
