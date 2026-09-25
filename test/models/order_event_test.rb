require "test_helper"

class OrderEventTest < ActiveSupport::TestCase
  def build_order
    customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
    address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
    product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}",
      price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
    cart = Cart.create!(session_token: SecureRandom.hex(10))
    cart.cart_items.create!(product: product, quantity: 1)
    Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
  end

  test "requires a kind" do
    event = OrderEvent.new(order: build_order)

    assert_not event.valid?
    assert_includes event.errors[:kind], "can't be blank"
  end

  test "is not a failure without an error_class" do
    event = OrderEvent.create!(order: build_order, kind: :order_confirmed, status: "confirmed")

    assert_not event.failure?
  end

  test "is a failure when error_class is present" do
    event = OrderEvent.create!(
      order: build_order, kind: :payment_authorize_failed, status: "failed",
      error_class: "Timeout::Error", error_message: "boom"
    )

    assert event.failure?
  end

  test "chronological orders events from oldest to newest" do
    order = build_order
    order.order_events.destroy_all
    older = OrderEvent.create!(order: order, kind: :order_created, status: "pending", created_at: 2.hours.ago)
    newer = OrderEvent.create!(order: order, kind: :order_confirmed, status: "confirmed", created_at: 1.hour.ago)

    assert_equal [ older, newer ], order.order_events.chronological.to_a
  end
end
