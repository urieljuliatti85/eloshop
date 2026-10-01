require "test_helper"

class CartReminderMailerTest < ActionMailer::TestCase
  setup do
    @customer = Customer.create!(name: "Maria", email: "maria-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @product = Product.create!(seller: sellers(:approved), name: "Caneca azul", sku: "MAIL-#{SecureRandom.hex(4)}",
      price_cents: 4_500, stock_quantity: 5, currency: "BRL", status: "active")
    @cart = Cart.create!(session_token: SecureRandom.hex(10), customer: @customer)
    @cart.cart_items.create!(product: @product, quantity: 2)
  end

  test "lists the items, links to the cart and offers an unsubscribe link and header" do
    mail = CartReminderMailer.reminder(@cart)

    assert_equal [ @customer.email ], mail.to
    assert_match "Caneca azul", mail.html_part.body.to_s
    assert_match "/cart", mail.html_part.body.to_s
    assert_match "/lembretes-de-carrinho/", mail.html_part.body.to_s
    assert_match "/lembretes-de-carrinho/", mail.text_part.body.to_s
    assert_match "/lembretes-de-carrinho/", mail["List-Unsubscribe"].to_s
  end

  test "sends nothing when no item can be bought any more" do
    @product.update_columns(status: "draft")

    assert_nil CartReminderMailer.reminder(@cart).message.to
  end
end
