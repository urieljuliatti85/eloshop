require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to customer login" do
    get new_order_payment_path(orders(:one))
    assert_redirected_to new_customer_session_path
  end

  test "a customer cannot access another customer's order payment" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:two))

    assert_response :not_found
  end

  test "an authenticated customer can view their own order's payment page" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:one))

    assert_response :success
  end

  test "an order without a payment attempt yet shows the payment method choice" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment

    get new_order_payment_path(order)

    assert_response :success
    assert_match "Como você quer pagar?", response.body
  end

  test "choosing pix creates a payment and redirects back to the payment page" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment

    assert_difference("Payment.count", 1) do
      post order_payment_path(order), params: { payment_method: "pix" }
    end

    assert_redirected_to new_order_payment_path(order)
    assert order.payments.sole.pending?
  end

  test "the card payment option only appears when the seller has a public key" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment

    get new_order_payment_path(order)

    assert_no_match "Pagar com cartão de crédito", response.body
  end

  test "the card payment option appears when the seller has a public key" do
    sign_in_customer(customers(:one))
    sellers(:approved).update!(
      mercado_pago_user_id: "mp-user-1",
      mercado_pago_public_key: "TEST-public-key",
      mercado_pago_access_token_ciphertext: "x",
      mercado_pago_refresh_token_ciphertext: "x"
    )
    order = build_order_without_payment

    get new_order_payment_path(order)

    assert_match "Pagar com cartão de crédito", response.body
  end

  test "choosing credit card authorizes synchronously and confirms the order" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment

    post order_payment_path(order),
      params: { payment_method: "credit_card", card_token: "any-token", installments: 2 }

    assert_redirected_to new_order_payment_path(order)
    payment = order.payments.sole
    assert payment.paid?
    assert order.reload.confirmed?
  end

  test "the payment page never renders a card number or CVV field" do
    sign_in_customer(customers(:one))

    get new_order_payment_path(orders(:one))

    assert_no_match(/name="card_number"|name="cvv"/, response.body)
  end

  test "status returns the latest payment without creating another attempt" do
    sign_in_customer(customers(:one))
    payment = payments(:one)

    get status_order_payment_path(orders(:one))

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal payment.id, orders(:one).payments.order(:created_at).last.id
    assert_equal 1, orders(:one).payments.count
  end

  test "status reports an expired pix without creating a replacement charge" do
    sign_in_customer(customers(:one))
    payment = payments(:one)
    payment.update!(pix_qr_code: "pix-code", expires_at: 1.minute.ago)

    assert_no_difference("Payment.count") do
      get status_order_payment_path(orders(:one))
    end

    assert_response :success
    assert_match(/recusado ou expirado/, response.body)
    assert_no_match(/data-controller="payment-status"/, response.body)
  end

  test "a customer cannot poll another customer's payment" do
    sign_in_customer(customers(:one))

    get status_order_payment_path(orders(:two))

    assert_response :not_found
  end

  private

  def sign_in_customer(customer)
    get new_customer_session_path
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  def build_order_without_payment
    customer = customers(:one)
    address = customer.addresses.first || customer.addresses.create!(
      street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000"
    )
    product = Product.create!(seller: sellers(:approved), name: "Produto teste", sku: "SKU-#{SecureRandom.hex(4)}",
                               price_cents: 1000, stock_quantity: 5, status: "active")
    cart = Cart.create!(session_token: SecureRandom.hex(10))
    cart.cart_items.create!(product: product, quantity: 1)

    Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
  end
end
