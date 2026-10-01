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

  test "refund_processed tells the buyer the amount, the method and that the timing depends on the bank" do
    order = build_order
    payment = order.payments.create!(
      gateway: "fake", status: :partially_refunded, external_id: "fake-1", amount_cents: order.total_cents,
      application_fee_cents: order.seller_order.platform_fee_cents, refunded_amount_cents: 500
    )
    refund = payment.payment_refunds.create!(idempotency_key: "mail-1", amount_cents: 500, application_fee_amount_cents: 0, status: :approved)

    email = OrderMailer.refund_processed(refund)

    assert_equal [ order.customer.email ], email.to
    assert_equal "Reembolso do pedido ##{order.id} — EloShop", email.subject
    html = email.html_part.body.to_s
    assert_match "reembolso parcial", html
    assert_match "R$ 5,00", html
    assert_match "PIX", html
    assert_match "depende do meio de pagamento", html
    assert_match "/orders/#{order.id}", email.text_part.body.to_s
  end

  test "refund_processed says total when the payment was fully refunded" do
    order = build_order
    payment = order.payments.create!(
      gateway: "fake", status: :refunded, external_id: "fake-2", amount_cents: order.total_cents,
      application_fee_cents: 0, refunded_amount_cents: order.total_cents
    )
    refund = payment.payment_refunds.create!(idempotency_key: "mail-2", amount_cents: order.total_cents, application_fee_amount_cents: 0, status: :approved)

    assert_match "reembolso total", OrderMailer.refund_processed(refund).html_part.body.to_s
  end
end
