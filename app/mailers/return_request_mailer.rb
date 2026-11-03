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
