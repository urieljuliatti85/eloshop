require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  def build_order
    customer = Customer.create!(name: "Maria", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
    address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
    product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
    cart = Cart.create!(session_token: SecureRandom.hex(10))
    cart.cart_items.create!(product: product, quantity: 1)
    Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
  end

  test "confirmation announces the payment and links to the order" do
    order = build_order

    email = OrderMailer.confirmation(order)
    body = email.body.to_s

    assert_equal [ order.customer.email ], email.to
    assert_match "Pagamento efetuado com sucesso", body
    assert_match "está em preparação", body
    assert_match "/orders/#{order.id}", body
  end
end
