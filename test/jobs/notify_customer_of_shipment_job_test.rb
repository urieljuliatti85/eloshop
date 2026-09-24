require "test_helper"

class NotifyCustomerOfShipmentJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  def build_seller_order(seller:)
    customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
    address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
    product = Product.create!(seller: seller, name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
    cart = Cart.create!(session_token: SecureRandom.hex(10))
    cart.cart_items.create!(product: product, quantity: 1)
    order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
    order.seller_order
  end

  test "envia para o e-mail do cliente com link para o pedido" do
    seller_order = build_seller_order(seller: sellers(:approved))
    seller_order.order.confirm!
    shipment = seller_order.create_shipment!(carrier: "Correios", service: "SEDEX", shipping_cents: 1500, estimated_days: 5)
    shipment.mark_shipped!(tracking_code: "AA123456789BR")

    assert_emails 1 do
      NotifyCustomerOfShipmentJob.perform_now(seller_order)
    end

    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, seller_order.order.customer.email
    assert_match "/orders/#{seller_order.order_id}", email.body.to_s
    assert_match "AA123456789BR", email.body.to_s
  end
end
