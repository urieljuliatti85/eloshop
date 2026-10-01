require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "e-mails saem de no-reply e respostas vão para contato" do
    email = WelcomeMailer.welcome_customer(customers(:one))

    assert_equal [ "no-reply@eloshop.shop" ], email.from
    assert_equal [ "contato@eloshop.shop" ], email.reply_to
  end

  test "mensagem de contato responde ao visitante, não a contato@" do
    email = ContactMailer.notify(name: "Maria", email: "maria@example.com", message: "Oi")

    assert_equal [ "no-reply@eloshop.shop" ], email.from
    assert_equal [ "maria@example.com" ], email.reply_to
  end

  test "mensagem de contato chega em contato@ por padrão" do
    email = ContactMailer.notify(name: "Maria", email: "maria@example.com", message: "Oi")

    assert_equal [ "contato@eloshop.shop" ], email.to
  end

  test "confirmação de contato vai para o visitante, com respostas para contato@" do
    email = ContactMailer.confirmation(email: "maria@example.com")

    assert_equal [ "maria@example.com" ], email.to
    assert_equal [ "no-reply@eloshop.shop" ], email.from
    assert_equal [ "contato@eloshop.shop" ], email.reply_to
    assert_equal "Recebemos sua mensagem — EloShop", email.subject
  end
end
