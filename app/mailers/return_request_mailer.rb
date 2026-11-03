# E-mails do comprador sobre a solicitação pós-venda (ADR 008). O protocolo já
# aparece na tela ao abrir; o e-mail é a cópia, não a confirmação legal.
class ReturnRequestMailer < ApplicationMailer
  def opened(return_request)
    @return_request = return_request
    @order = return_request.order

    mail(
      to: @order.customer.email,
      subject: "Solicitação #{return_request.protocol} recebida — pedido ##{@order.id}"
    )
  end

  # Cópia por e-mail do aviso do painel do ateliê, em toda movimentação da
  # solicitação (ReturnRequests::Notifications). O ateliê não decide: o texto
  # diz o que aconteceu e, na desistência antes do envio, que não envie.
  def seller_notice(return_request, recipient, title, message)
    @return_request = return_request
    @order = return_request.order
    @message = message

    mail(to: recipient, subject: "#{title} — EloShop")
  end

  def updated(return_request_update)
    @update = return_request_update
    @return_request = return_request_update.return_request
    @order = @return_request.order

    mail(
      to: @order.customer.email,
      subject: "Atualização da solicitação #{@return_request.protocol} — pedido ##{@order.id}"
    )
  end
end
