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

  # O "Tentar novamente" da tela de falha levava a esta mesma ação sem o
  # parâmetro, que reencontrava a tentativa travada e renderizava de novo a
  # mesma mensagem de erro: beco sem saída, observado em produção em
  # 2026-09-12. Para cartão a volta à escolha é a única saída possível, porque
  # o token do Brick é de uso único.
  test "retrying a stalled attempt returns to the payment method choice" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment
    order.payments.create!(
      gateway: "fake", status: "processing", payment_method: "credit_card",
      amount_cents: order.total_cents, idempotency_key: SecureRandom.uuid,
      created_at: (Payment::PROCESSING_STALE_AFTER + 1.minute).ago
    )

    get new_order_payment_path(order, retry: 1)

    assert_response :success
    assert_match "Como você quer pagar?", response.body
  end

  # A contrapartida: uma cobrança válida não pode ser refeita por um parâmetro
  # na URL — seria o caminho para cobrar o cliente duas vezes.
  test "retrying does nothing when the payment is still valid" do
    sign_in_customer(customers(:one))
    order = build_order_without_payment
    order.payments.create!(
      gateway: "fake", status: "paid", payment_method: "credit_card",
      external_id: "mp-#{SecureRandom.hex(4)}",
      amount_cents: order.total_cents, idempotency_key: SecureRandom.uuid
    )

    get new_order_payment_path(order, retry: 1)

    assert_response :success
    assert_no_match "Como você quer pagar?", response.body
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

  # O SDK injeta em runtime um <script> inline com o widget antifraude e só
  # aplica nonce nele se receber `deviceProfileCspNonce`. Sem esse valor a CSP
  # bloqueia o script: o Brick fica preso no skeleton e o antifraude não roda
  # — observado em produção em 2026-09-12. O nonce tem de ser o mesmo do
  # cabeçalho, senão o browser bloqueia igual.
  test "the card brick receives the same csp nonce sent in the header" do
    sign_in_customer(customers(:one))
    sellers(:approved).update!(
      mercado_pago_user_id: "mp-user-1",
      mercado_pago_public_key: "TEST-public-key",
      mercado_pago_access_token_ciphertext: "x",
      mercado_pago_refresh_token_ciphertext: "x"
    )
    order = build_order_without_payment

    get new_order_payment_path(order)

    nonce = response.body[/data-card-payment-brick-csp-nonce-value="([^"]+)"/, 1]
    assert nonce.present?, "o Brick precisa receber um nonce"
    assert_includes response.headers["Content-Security-Policy"], "'nonce-#{nonce}'"
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
    # A asserção olha o que o cliente precisa saber — que falhou e que dá para
    # tentar de novo — em vez da redação exata, que já mudou uma vez.
    assert_match(/Não foi possível concluir o pagamento/, response.body)
    assert_match(/Tentar novamente/, response.body)
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
