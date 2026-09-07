require "test_helper"

class RecordOrderAnalyticsJobTest < ActiveJob::TestCase
  def build_order
    customer = Customer.create!(name: "Cliente Analytics", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
    address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
    product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 2500, stock_quantity: 5, currency: "BRL", status: "active")
    cart = Cart.create!(session_token: SecureRandom.hex(10))
    cart.cart_items.create!(product: product, quantity: 2)
    Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
  end

  test "emite o evento de pedido confirmado com os valores do pedido" do
    order = build_order

    capture_rails_events("order.confirmed") do |events|
      RecordOrderAnalyticsJob.perform_now(order)

      assert_equal 1, events.size
      payload = events.first[:payload]

      assert_equal order.id, payload[:order_id]
      assert_equal order.customer_id, payload[:customer_id]
      assert_equal sellers(:approved).id, payload[:seller_id]
      assert_equal 2, payload[:item_count]
      assert_equal order.total_cents, payload[:total_cents]
      assert_equal order.seller_order.platform_fee_cents, payload[:platform_fee_cents]
      assert_equal order.seller_order.seller_amount_cents, payload[:seller_amount_cents]
    end
  end

  # §43: analytics é dado agregável, não dossiê. O `customer_id` correlaciona
  # sem expor a pessoa; nome, e-mail e endereço não podem vazar para o log.
  test "não registra dado pessoal do cliente" do
    order = build_order

    capture_rails_events("order.confirmed") do |events|
      RecordOrderAnalyticsJob.perform_now(order)

      serialized = events.first[:payload].to_s
      refute_includes serialized, order.customer.email
      refute_includes serialized, order.customer.name
      refute_includes serialized, order.shipping_address_snapshot["street"]
    end
  end
end
