module Gateways
  # Reembolso que o admin já fez por fora do Mercado Pago e só registra aqui.
  # Tem a mesma interface de `refund` dos gateways para Payments::Refund
  # reaproveitar tudo — reserva do valor, travas, chargeback, comissão
  # proporcional e avisos — sem um segundo caminho de contabilidade. O
  # dinheiro já saiu, então a resposta é sempre aprovada e sem id externo.
  class ManualRefund
    def name
      "manual"
    end

    def refund(payment:, amount_cents:, idempotency_key:)
      RefundIntent.new(external_id: nil, status: "approved")
    end
  end
end
