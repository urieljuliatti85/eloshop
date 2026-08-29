class PaymentWebhooksController < ApplicationController
  # Um gateway de verdade chamando este endpoint não tem token CSRF — a
  # autenticidade do webhook é garantida pelo segredo verificado abaixo, não
  # pela proteção CSRF (que é para formulários de navegador).
  skip_forgery_protection

  allow_unauthenticated_access

  def create
    gateway = Gateways::FakeGateway.new
    return head :unauthorized unless gateway.verify_webhook(params[:secret])

    Payments::ProcessWebhook.new(
      event_id: params[:event_id],
      external_id: params[:external_id],
      status: params[:status]
    ).call

    payment = Payment.find_by(external_id: params[:external_id])
    return head :unprocessable_entity unless payment

    # A resposta real de um webhook não redireciona (ver docs/payments.md) —
    # o redirecionamento aqui existe só porque, no gateway fake, este mesmo
    # endpoint também é o alvo dos botões de simulação na UI.
    redirect_to new_order_payment_path(payment.order)
  rescue Payments::ProcessWebhook::OrderNotFound
    head :unprocessable_entity
  end
end
