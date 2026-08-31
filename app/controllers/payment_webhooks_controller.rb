class PaymentWebhooksController < ApplicationController
  # Um gateway de verdade chamando este endpoint não tem token CSRF — a
  # autenticidade do webhook é garantida pela assinatura verificada abaixo
  # (comparação timing-safe), não pela proteção CSRF (que é para formulários de
  # navegador). Removido por engano por um autofix automático do CodeQL/Copilot
  # que não reconheceu esse padrão — sem isso, todo webhook real recebe 422
  # ActionController::InvalidAuthenticityToken e nenhum pagamento é confirmado.
  # Ver docs/security.md, seção Webhooks.
  skip_forgery_protection

  allow_unauthenticated_access

  def create
    gateway = Gateways.build

    return head :unauthorized unless gateway.verify_webhook(request)

    event = gateway.webhook_event(request)
    return head :unprocessable_entity if event.blank? || event[:external_id].blank?

    Payments::ProcessWebhook.new(**event).call

    payment = Payment.find_by(external_id: event[:external_id])
    return head :unprocessable_entity unless payment

    respond_to_gateway(gateway, payment)
  rescue Payments::ProcessWebhook::OrderNotFound
    head :unprocessable_entity
  end

  private

  # Um webhook real não redireciona: o gateway espera só um 200 para parar de
  # reenviar. O redirecionamento existe apenas no gateway fake, onde este mesmo
  # endpoint é o alvo dos botões de simulação na tela de pagamento.
  def respond_to_gateway(gateway, payment)
    if gateway.is_a?(Gateways::FakeGateway)
      redirect_to new_order_payment_path(payment.order)
    else
      head :ok
    end
  end
end
