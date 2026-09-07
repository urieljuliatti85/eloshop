class ApplicationMailer < ActionMailer::Base
  # Mailer não herda os helpers de view da aplicação; sem isso, `format_price`
  # (usado nos e-mails de pedido para não imprimir centavos crus) não existe
  # no template.
  helper ApplicationHelper

  default from: "from@example.com"
  layout "mailer"
end
