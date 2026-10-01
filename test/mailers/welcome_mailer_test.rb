require "test_helper"

class WelcomeMailerTest < ActionMailer::TestCase
  test "welcome_customer greets the customer and links to their account" do
    customer = customers(:one)

    email = WelcomeMailer.welcome_customer(customer)

    assert_equal [ customer.email ], email.to
    assert_equal "Bem-vindo à EloShop, #{customer.name}!", email.subject
    assert_match customer.name, email.html_part.body.to_s
    assert_match "/minha-conta", email.html_part.body.to_s
    assert_match "/minha-conta", email.text_part.body.to_s
  end

  test "welcome_seller greets the seller and links to the seller panel" do
    seller = sellers(:approved)

    email = WelcomeMailer.welcome_seller(seller, "dono@example.com")

    assert_equal [ "dono@example.com" ], email.to
    assert_equal "Bem-vindo à EloShop, #{seller.name}!", email.subject
    assert_match seller.name, email.html_part.body.to_s
    assert_match "/painel", email.html_part.body.to_s
    assert_match "/painel", email.text_part.body.to_s
  end

  test "welcome_seller puts the Mercado Pago connection first and links to the step-by-step guide" do
    email = WelcomeMailer.welcome_seller(sellers(:approved), "dono@example.com")

    assert_match "/painel/primeiros-passos", email.html_part.body.to_s
    assert_match "/painel/primeiros-passos", email.text_part.body.to_s
    assert_operator email.text_part.body.to_s.index("Mercado Pago"), :<, email.text_part.body.to_s.index("endereço de origem")
  end
end
