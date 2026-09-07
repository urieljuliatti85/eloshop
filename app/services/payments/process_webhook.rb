module Payments
  # Processa um evento de webhook do gateway de pagamento, de forma
  # idempotente (ver docs/payments.md, "Webhooks"): o mesmo evento recebido
  # mais de uma vez nunca duplica efeito (nem paga duas vezes, nem tenta
  # confirmar um pedido já confirmado).
  class ProcessWebhook
    class OrderNotFound < StandardError; end

    def initialize(event_id:, external_id:, status:, processor_fee_cents: nil)
      @event_id = event_id
      @external_id = external_id
      @status = status
      @processor_fee_cents = processor_fee_cents
    end

    def call
      return if PaymentEvent.exists?(gateway_event_id: @event_id)

      payment = nil
      confirmed = false
      ActiveRecord::Base.transaction do
        payment = Payment.find_by(external_id: @external_id)
        raise OrderNotFound, "pagamento não encontrado para external_id=#{@external_id}" unless payment

        payment.payment_events.create!(
          gateway_event_id: @event_id,
          payload: { status: @status },
          processed_at: Time.current
        )

        confirmed = apply_status!(payment)
      end

      # Fora da transação de propósito: enfileirar dentro dela colocaria o
      # job na fila antes do commit, e o worker poderia lê-lo (banco `queue`
      # separado, ver CLAUDE.md) antes de o pedido existir para ele.
      notify_confirmation(payment.order) if confirmed

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

    # Devolve `true` somente quando ESTE evento foi o que confirmou o pedido
    # — é o que autoriza o fan-out. A guarda de idempotência é a máquina de
    # estados: `confirmed` não transiciona para `confirmed`, então um webhook
    # repetido (ou a confirmação síncrona do cartão chegando junto do
    # webhook) não dispara os avisos duas vezes.
    def apply_status!(payment)
      case @status
      when "approved"
        return false if payment.partially_refunded? || payment.refunded?

        attributes = { status: "paid" }
        attributes[:processor_fee_cents] = @processor_fee_cents unless @processor_fee_cents.nil?
        payment.update!(attributes)
        return false if payment.order.confirmed?

        payment.order.confirm!
        true
      when "declined"
        return false if payment.paid? || payment.partially_refunded? || payment.refunded?

        payment.update!(status: "failed")
        false
      else
        false
      end
    end

    # Fan-out do pedido confirmado. Cada aviso é um job próprio para que a
    # falha de um não impeça os outros: se o e-mail do cliente falhar, o
    # artesão ainda é avisado e a venda ainda é registrada (CLAUDE.md §49,
    # §50 — a compra não depende da entrega imediata de um e-mail).
    def notify_confirmation(order)
      SendOrderConfirmationJob.perform_later(order)
      order.seller_orders.each { |seller_order| NotifySellerOfOrderJob.perform_later(seller_order) }
      RecordOrderAnalyticsJob.perform_later(order)
    end
  end
end
