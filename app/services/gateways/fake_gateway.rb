module Gateways
  # Gateway simulado — não há integração real ainda (ver docs/payments.md,
  # TODO — DECISION REQUIRED resolvido para o MVP como "gateway fake").
  # Implementa só o que o MVP precisa: authorize e verify_webhook.
  class FakeGateway
    Intent = Struct.new(:external_id)

    # Segredo compartilhado do gateway fake — não é segurança real, já que
    # não existe dinheiro de verdade em jogo aqui. Serve só para exercitar o
    # requisito de "webhook autenticado" (ver docs/security.md).
    WEBHOOK_SECRET = "fake-gateway-dev-secret"

    def name
      "fake"
    end

    def authorize(order:)
      Intent.new("fake_#{SecureRandom.hex(10)}")
    end

    def verify_webhook(secret)
      ActiveSupport::SecurityUtils.secure_compare(secret.to_s, WEBHOOK_SECRET)
    end
  end
end
