require "test_helper"

class FullPurchaseFlowTest < ActionDispatch::IntegrationTest
  test "product published to order confirmed, end to end" do
    admin = users(:one)
    product = Product.create!(seller: sellers(:approved), name: "Vaso de cerâmica", sku: "E2E-#{SecureRandom.hex(4)}", price_cents: 5000, stock_quantity: 3, currency: "BRL", status: "draft",
      weight_grams: 500, length_cm: 20, width_cm: 15, height_cm: 10)

    # Admin publica o produto
    sign_in_admin(admin)
    patch publish_admin_product_path(product)
    assert product.reload.active?
    sign_out_admin

    # Cliente navega o catálogo e vê o produto publicado
    get products_path
    assert_select "a", text: /#{product.name}/

    get product_path(product.seller, product.slug)
    assert_response :success

    # Cliente se identifica
    customer = Customer.create!(name: "Cliente E2E", email: "e2e-#{SecureRandom.hex(4)}@example.com", password: "password123")
    address = customer.addresses.create!(street: "Rua E2E", number: "1", neighborhood: "Centro", city: "Cidade", state: "SP", zip_code: "00000-000")
    post customer_session_path, params: { email: customer.email, password: "password123" }

    # Cliente adiciona ao carrinho
    post cart_items_path, params: { product_id: product.id, quantity: 1 }
    get cart_path
    assert_match product.name, response.body

    # Cliente finaliza o checkout
    assert_difference("Order.count", 1) do
      post orders_path, params: { address_id: address.id }
    end
    order = Order.last
    assert_redirected_to new_order_payment_path(order)
    assert order.pending?
    assert_equal 2, product.reload.stock_quantity

    # Cliente segue diretamente para a página de pagamento
    follow_redirect!
    assert_response :success
    payment = order.payments.last
    assert payment.pending?

    # Gateway (simulado) aprova o pagamento via webhook
    post fake_gateway_webhook_path, params: {
      event_id: SecureRandom.hex(10),
      external_id: payment.external_id,
      status: "approved",
      secret: Gateways::FakeGateway::WEBHOOK_SECRET
    }

    assert payment.reload.paid?
    assert order.reload.confirmed?

    # Cliente vê o pedido confirmado
    get order_path(order)
    assert_response :success
    assert_select "p", text: /Status: confirmed/
  end

  private

  def sign_in_admin(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out_admin
    delete session_path
  end
end
