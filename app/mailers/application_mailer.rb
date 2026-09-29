class ApplicationMailer < ActionMailer::Base
  # Mailer não herda os helpers de view da aplicação; sem isso, `format_price`
  # (usado nos e-mails de pedido para não imprimir centavos crus) não existe
  # no template.
  helper ApplicationHelper

  # Repete falhas transitórias de envio no `deliver_later`.
  self.delivery_job = ApplicationMailDeliveryJob

  # no-reply não recebe nada: respostas dos clientes vão para contato@, que o
  # Cloudflare Email Routing encaminha à caixa do negócio.
  default from: "EloShop <no-reply@eloshop.shop>", reply_to: "contato@eloshop.shop"
  layout "mailer"
end
