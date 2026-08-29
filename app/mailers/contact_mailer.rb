class ContactMailer < ApplicationMailer
  DESTINATION_EMAIL = ENV.fetch("CONTACT_EMAIL", "uriel.juliattivalle@gmail.com")

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
end
