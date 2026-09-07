require "test_helper"

class NotifySellerOfOrderJobTest < ActiveJob::TestCase
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

  test "envia para o usuário do ateliê" do
    seller_order = build_seller_order(seller: sellers(:approved))
    recipient = sellers(:approved).users.order(:created_at).first.email_address

    assert_emails 1 do
      NotifySellerOfOrderJob.perform_now(seller_order)
    end

    assert_includes ActionMailer::Base.deliveries.last.to, recipient
  end

  # Um ateliê aprovado pode não ter usuário vinculado (criado pelo admin, por
  # exemplo). Isso não é erro: não há para onde enviar, e repetir o job não
  # faria aparecer um destinatário.
  test "não envia nem levanta erro quando o ateliê não tem usuário" do
    seller = Seller.create!(name: "Ateliê sem usuário #{SecureRandom.hex(4)}", status: :approved, approved_at: Time.current)
    seller_order = build_seller_order(seller: seller)

    assert_empty seller.users

    assert_no_emails do
      assert_nothing_raised { NotifySellerOfOrderJob.perform_now(seller_order) }
    end
  end
end
