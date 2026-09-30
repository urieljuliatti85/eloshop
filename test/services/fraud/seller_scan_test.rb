require "test_helper"

module Fraud
  class SellerScanTest < ActiveSupport::TestCase
    setup do
      @seller = sellers(:approved)
      @now = Time.current
    end

    def scan
      SellerScan.new(now: @now).call
    end

    def connect_mercado_pago!(seller, live_mode: true, test_account: false)
      seller.update!(
        mercado_pago_user_id: "u#{seller.id}", mercado_pago_access_token_ciphertext: "x",
        mercado_pago_refresh_token_ciphertext: "y", mercado_pago_connected_at: @now,
        mercado_pago_live_mode: live_mode, mercado_pago_test_account: test_account
      )
    end

    def build_order(email: "cliente-#{SecureRandom.hex(3)}@example.com", product_attrs: {})
      customer = Customer.create!(name: "Cliente", email: email, password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!({ seller: @seller, name: "P #{SecureRandom.hex(4)}", sku: "SKU-#{SecureRandom.hex(4)}",
        price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active" }.merge(product_attrs))
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
    end

    def paid_order(days_ago:, **options)
      order = build_order(**options)
      order.confirm!
      order.update_columns(created_at: days_ago.days.ago)
      order.order_events.destroy_all
      order
    end

    def alerts_for(rule)
      FraudAlert.open.where(rule: rule)
    end

    # --- conta não real ---------------------------------------------------

    test "flags an approved seller whose connected account is a test account" do
      connect_mercado_pago!(@seller, test_account: true)

      assert_equal [ "unverified_account" ], scan.map(&:rule)
    end

    test "flags an approved seller whose account origin is unknown" do
      connect_mercado_pago!(@seller, test_account: nil)

      assert_equal [ "unverified_account" ], scan.map(&:rule)
    end

    test "does not flag a real connected account" do
      connect_mercado_pago!(@seller, test_account: false)

      assert_empty scan
    end

    test "does not flag an approved seller that is not connected, like the platform's own" do
      assert_not_predicate @seller, :mercado_pago_connected?

      assert_empty scan
    end

    test "does not flag a pending seller" do
      pending = sellers(:pending)
      connect_mercado_pago!(pending, test_account: true)

      assert_empty scan
    end

    # --- autocompra -------------------------------------------------------

    test "flags a paid order bought with the seller's own e-mail" do
      order = paid_order(days_ago: 0, email: "SELLER@example.com")

      alert = scan.find { |a| a.rule == "self_purchase" }

      assert_equal @seller, alert.seller
      assert_equal [ order.id ], alert.detail["order_ids"]
    end

    test "ignores an unpaid order bought with the seller's own e-mail" do
      build_order(email: "seller@example.com")

      assert_empty alerts_for("self_purchase").to_a + scan.select { |a| a.rule == "self_purchase" }
    end

    # --- pedido pago sem envio --------------------------------------------

    test "flags a paid order still unshipped after seven days" do
      order = paid_order(days_ago: 8)

      alert = scan.find { |a| a.rule == "unshipped_paid_order" }

      assert_equal [ order.id ], alert.detail["order_ids"]
    end

    test "does not flag a paid order inside the seven days" do
      paid_order(days_ago: 6)

      assert_empty scan
    end

    test "adds the production time to the deadline of a made-to-order product" do
      paid_order(days_ago: 10, product_attrs: { availability_type: "made_to_order", production_time_min_days: 5, production_time_max_days: 10 })

      assert_empty scan

      travel_to 10.days.from_now do
        assert_equal [ "unshipped_paid_order" ], SellerScan.new.call.map(&:rule)
      end
    end

    test "auto-resolves the alert once the order is shipped" do
      order = paid_order(days_ago: 8)
      scan
      order.seller_order.shipment.mark_shipped!(tracking_code: "BR123")

      assert_empty scan
      assert_empty alerts_for("unshipped_paid_order")
    end

    # --- envio sem rastreio -----------------------------------------------

    test "flags a shipment without tracking code after seven days" do
      order = paid_order(days_ago: 9)
      order.seller_order.shipment.mark_shipped!
      order.seller_order.shipment.update_columns(shipped_at: 8.days.ago)

      assert_equal [ "shipped_without_tracking" ], scan.map(&:rule)
    end

    test "does not flag a shipment with tracking code" do
      order = paid_order(days_ago: 9)
      order.seller_order.shipment.mark_shipped!(tracking_code: "BR999")
      order.seller_order.shipment.update_columns(shipped_at: 8.days.ago)

      assert_empty scan
    end

    # --- idempotência e fechamento ----------------------------------------

    test "a second run does not create another alert nor report it again" do
      connect_mercado_pago!(@seller, test_account: true)

      assert_equal 1, scan.size
      assert_no_difference -> { FraudAlert.count } do
        assert_empty scan
      end
    end

    test "a manual alert is never auto-resolved even when the signal goes away" do
      connect_mercado_pago!(@seller, test_account: true)
      scan
      connect_mercado_pago!(@seller, test_account: false)

      scan

      assert_equal 1, alerts_for("unverified_account").count
    end

    test "a resolved alert is reopened if the signal is still there" do
      connect_mercado_pago!(@seller, test_account: true)
      scan
      FraudAlert.last.resolve!

      assert_equal [ "unverified_account" ], scan.map(&:rule)
      assert_equal 2, FraudAlert.where(rule: "unverified_account").count
    end

    test "refreshes the detail of an open alert without reporting it again" do
      first = paid_order(days_ago: 8)
      scan
      second = paid_order(days_ago: 9)

      assert_empty scan
      assert_equal [ first.id, second.id ].sort, alerts_for("unshipped_paid_order").sole.detail["order_ids"]
    end
  end
end
