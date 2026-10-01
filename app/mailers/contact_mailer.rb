class ContactMailer < ApplicationMailer
  DESTINATION_EMAIL = ENV.fetch("CONTACT_EMAIL", "contato@eloshop.shop")

  def notify(name:, email:, message:, subject: nil)
    @name = name
    @email = email
    @message = message
    @subject = subject

    mail(
      to: DESTINATION_EMAIL,
      reply_to: email,
      subject: subject.presence || "Nova mensagem de contato — EloShop"
    )
  end

  # Confirma ao visitante que a mensagem chegou e quando ele terá resposta.
  # Texto fixo, de propósito: o formulário é aberto e o e-mail do destinatário
  # é só o que a pessoa digitou, então nada do que ela escreveu (nome, assunto,
  # mensagem) volta no e-mail. Senão qualquer um usaria a EloShop para mandar
  # texto de sua escolha a um terceiro.
  def confirmation(email:)
    mail(to: email, subject: "Recebemos sua mensagem — EloShop")
  end
end
