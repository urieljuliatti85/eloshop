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
end
