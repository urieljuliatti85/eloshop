require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "customer_reset sends the buyer a link to the storefront reset page, valid for 15 minutes" do
    customer = Customer.create!(name: "Maria", email: "mailer-#{SecureRandom.hex(4)}@example.com", password: "password123")

    email = PasswordsMailer.customer_reset(customer)

    assert_equal [ customer.email ], email.to
    assert_equal "Redefinição de senha — EloShop", email.subject
    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |body|
      assert_match "/recuperar-senha/", body
      assert_no_match(%r{/passwords/}, body, "o comprador não pode ser levado à tela de admin e vendedor")
      assert_match "15 minutos", body
    end
  end

  test "reset gives admins and sellers the same clear layout as the buyer: greeting, button, expiry and an ignore note" do
    user = users(:one)

    email = PasswordsMailer.reset(user)

    assert_equal [ user.email_address ], email.to
    assert_equal "Redefinição de senha — EloShop", email.subject
    html = email.html_part.body.to_s
    assert_match "Criar nova senha", html
    assert_match "pode ignorar este e-mail", html
    [ html, email.text_part.body.to_s ].each do |body|
      assert_match %r{/passwords/[^/]+/edit}, body
      assert_no_match(%r{/recuperar-senha/}, body, "admin e vendedor não vão para a tela do comprador")
      assert_match "15 minutos", body
    end
  end
end
