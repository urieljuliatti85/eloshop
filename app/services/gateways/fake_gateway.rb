module Gateways
  # Gateway simulado, usado em desenvolvimento e teste (e em produção enquanto
  # PAYMENT_GATEWAY não for definido — ver Gateways.build).
  #
  # Implementa a mesma interface do adapter real para que a troca não exija
  # mudança em Payment, PaymentEvent ou nos services (ADR 003):
  # name / authorize / verify_webhook / webhook_event / payment_status.
  class FakeGateway
    # Segredo compartilhado do gateway fake — não é segurança real, já que não
    # existe dinheiro de verdade em jogo aqui. Serve para exercitar o requisito
    # de "webhook autenticado" (ver docs/security.md).
    WEBHOOK_SECRET = "fake-gateway-dev-secret"

    def name
      "fake"
    end

    def authorize(order:)
      Intent.new(external_id: "fake_#{SecureRandom.hex(10)}")
    end

    def verify_webhook(request)
      ActiveSupport::SecurityUtils.secure_compare(request.params[:secret].to_s, WEBHOOK_SECRET)
    end

    # No gateway fake a própria requisição carrega o desfecho, porque quem a
    # dispara são os botões de simulação na tela de pagamento. Um gateway real
    # nunca confia no que vem no corpo — o adapter do Mercado Pago consulta a
    # API para descobrir o status.
    def webhook_event(request)
      {
        event_id: request.params[:event_id],
        external_id: request.params[:external_id],
        status: request.params[:status]
      }
    end

    def payment_status(external_id:)
      Payment.find_by(external_id: external_id)&.status || "pending"
    end
  end
end
