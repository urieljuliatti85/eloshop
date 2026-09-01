module Payments
  # Processa um evento de webhook do gateway de pagamento, de forma
  # idempotente (ver docs/payments.md, "Webhooks"): o mesmo evento recebido
  # mais de uma vez nunca duplica efeito (nem paga duas vezes, nem tenta
  # confirmar um pedido já confirmado).
  class ProcessWebhook
    class OrderNotFound < StandardError; end

    def initialize(event_id:, external_id:, status:)
      @event_id = event_id
      @external_id = external_id
      @status = status
    end

    def call
      return if PaymentEvent.exists?(gateway_event_id: @event_id)

      payment = nil
      ActiveRecord::Base.transaction do
        payment = Payment.find_by(external_id: @external_id)
        raise OrderNotFound, "pagamento não encontrado para external_id=#{@external_id}" unless payment

        payment.payment_events.create!(
          gateway_event_id: @event_id,
          payload: { status: @status },
          processed_at: Time.current
        )

        apply_status!(payment)
      end

      Rails.event.notify(
        "payment.webhook_applied",
        payment_id: payment.id,
        order_id: payment.order_id,
        gateway: payment.gateway,
        status: payment.status
      )

      payment
    rescue ActiveRecord::RecordNotUnique
      nil # evento concorrente já processado por outra requisição
    end

    private

    def apply_status!(payment)
      case @status
      when "approved"
        payment.update!(status: "paid")
        payment.order.confirm! unless payment.order.confirmed?
      when "declined"
        payment.update!(status: "failed")
      end
    end
  end
end
