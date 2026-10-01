require "test_helper"

module Orders
  class CancelAbandonedTest < ActiveSupport::TestCase
    def build_order(stock_quantity: 5)
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000, stock_quantity: stock_quantity, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      [ order, product ]
    end

    def attempt(order, status: "processing", created_at: 2.hours.ago, external_id: nil)
      order.payments.create!(
        gateway: "fake", status: status, amount_cents: order.total_cents,
        application_fee_cents: order.seller_order.platform_fee_cents, idempotency_key: SecureRandom.uuid,
        external_id: external_id, created_at: created_at
      )
    end

    def gateway_returning(result)
      gateway = Object.new
      gateway.define_singleton_method(:find_payment_for) { |order:| result.respond_to?(:call) ? result.call : result }
      gateway
    end

    test "cancels the order and restores stock when the gateway never created the charge" do
      order, product = build_order(stock_quantity: 5)
      assert_equal 4, product.reload.stock_quantity
      attempt(order)

      CancelAbandoned.new(gateway: gateway_returning(nil)).call

      assert order.reload.cancelled?
      assert_equal 5, product.reload.stock_quantity
    end

    test "keeps the order and records the charge when it exists at the gateway" do
      order, product = build_order
      payment = attempt(order)
      remote = Gateways::RemotePayment.new(external_id: "mp-123", status: "approved")

      CancelAbandoned.new(gateway: gateway_returning(remote)).call

      assert order.reload.pending?
      assert_equal 4, product.reload.stock_quantity
      payment.reload
      assert payment.pending?
      assert_equal "mp-123", payment.external_id
    end

    test "does nothing when it cannot ask the gateway, so it never cancels on a guess" do
      order, product = build_order
      payment = attempt(order)
      failing = gateway_returning(-> { raise Gateways::MercadoPago::RequestFailed, "Mercado Pago respondeu 500" })

      assert_nothing_raised { CancelAbandoned.new(gateway: failing).call }

      assert order.reload.pending?
      assert_equal 4, product.reload.stock_quantity
      assert payment.reload.processing?
    end

    test "leaves a recent attempt alone" do
      order, = build_order
      attempt(order, created_at: 10.minutes.ago)

      CancelAbandoned.new(gateway: gateway_returning(nil)).call

      assert order.reload.pending?
    end

    test "leaves alone an order that also has a live payment" do
      order, = build_order
      attempt(order)
      attempt(order, status: "pending", external_id: "mp-live", created_at: 30.minutes.ago)

      CancelAbandoned.new(gateway: gateway_returning(nil)).call

      assert order.reload.pending?
    end

    test "ignores orders that are not pending" do
      order, = build_order
      attempt(order)
      order.confirm!

      CancelAbandoned.new(gateway: gateway_returning(nil)).call

      assert order.reload.confirmed?
    end

    test "the periodic job runs it together with the expired-PIX cancellation" do
      order, = build_order
      attempt(order)

      CancelExpiredOrdersJob.perform_now

      assert order.reload.cancelled?
    end
  end
end
