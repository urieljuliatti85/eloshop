module Payments
  # Consulta o gateway para pagamentos que ficaram pendentes por mais tempo que
  # o esperado, cobrindo o caso em que o webhook não chegou ou foi descartado.
  #
  # Usa ProcessWebhook para aplicar o status, o que garante idempotência: se
  # o webhook original já processou o pagamento, a reconciliação é no-op. Se
  # não chegou, a reconciliação age como um webhook tardio.
  #
  # O event_id gerado aqui é distinto do event_id do webhook real
  # ("mp-<id>-<status>-...") de propósito: ambos ficam no histórico e o
  # rastreio revela o que aconteceu — webhook não chegou, reconciliação
  # corrigiu.
  class Reconcile
    # Pagamentos pendentes com menos de MINIMUM_AGE ainda podem receber o
    # webhook dentro do prazo normal de entrega do Mercado Pago.
    MINIMUM_AGE = 10.minutes
    BATCH_SIZE = 50

    def initialize(gateway: Gateways.build)
      @gateway = gateway
    end

    def call
      stale_payments.find_each(batch_size: BATCH_SIZE) do |payment|
        reconcile_payment(payment)
      end
    end

    private

    def stale_payments
      Payment.pending
        .where.not(external_id: nil)
        .where(gateway: @gateway.name)
        .where("payments.created_at <= ?", MINIMUM_AGE.ago)
    end

    def reconcile_payment(payment)
      status = @gateway.payment_status(external_id: payment.external_id)
      return if status == "pending"

      event_id = "reconcile-#{payment.external_id}-#{status}"
      ProcessWebhook.new(
        event_id: event_id,
        external_id: payment.external_id,
        status: status
      ).call

      Rails.event.notify(
        "payment.reconciled",
        payment_id: payment.id,
        order_id: payment.order_id,
        gateway: payment.gateway,
        status: status
      )
    rescue StandardError => e
      Rails.event.notify(
        "payment.reconcile_failed",
        payment_id: payment.id,
        external_id: payment.external_id,
        error: e.class.name
      )
    end
  end
end
