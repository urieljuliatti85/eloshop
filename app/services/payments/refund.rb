module Payments
  class Refund
    class InvalidRefund < StandardError; end

    def initialize(payment:, amount_cents:, idempotency_key:, gateway: Gateways.build(payment.gateway))
      @payment = payment
      @amount_cents = amount_cents.to_i
      @idempotency_key = idempotency_key
      @gateway = gateway
    end

    def call
      existing = PaymentRefund.find_by(idempotency_key: @idempotency_key)
      if existing && existing.payment_id != @payment.id
        raise InvalidRefund, "chave de idempotência pertence a outro pagamento"
      end
      return existing if existing&.approved?

      refund = prepare_refund
      return refund unless refund.processing?

      intent = @gateway.refund(
        payment: @payment,
        amount_cents: refund.amount_cents,
        idempotency_key: refund.idempotency_key
      )

      apply_refund!(refund, intent)
    rescue ActiveRecord::RecordNotUnique
      concurrent = PaymentRefund.find_by!(idempotency_key: @idempotency_key)
      raise InvalidRefund, "chave de idempotência pertence a outro pagamento" if concurrent.payment_id != @payment.id

      concurrent
    end

    private

    def prepare_refund
      @payment.with_lock do
        existing = @payment.payment_refunds.find_by(idempotency_key: @idempotency_key)
        return existing if existing

        unless @payment.paid? || @payment.partially_refunded?
          raise InvalidRefund, "somente pagamentos confirmados podem ser reembolsados"
        end
        processing_refunds = @payment.payment_refunds.processing
        reserved_cents = processing_refunds.sum(:amount_cents)
        reserved_fee_cents = processing_refunds.sum(:application_fee_amount_cents)
        available_cents = @payment.remaining_refundable_cents - reserved_cents
        unless @amount_cents.positive? && @amount_cents <= available_cents
          raise InvalidRefund, "valor de reembolso inválido"
        end

        seller_order = @payment.order.seller_order
        @payment.payment_refunds.create!(
          idempotency_key: @idempotency_key,
          amount_cents: @amount_cents,
          application_fee_amount_cents: seller_order.platform_fee_refund_for(
            @amount_cents,
            reserved_amount_cents: reserved_cents,
            reserved_fee_cents: reserved_fee_cents
          )
        )
      end
    end

    def apply_refund!(refund, intent)
      ActiveRecord::Base.transaction do
        @payment.lock!
        refund.lock!
        return refund if refund.approved?

        unless intent.status == "approved"
          refund.update!(external_id: intent.external_id, status: intent.status)
          return refund
        end

        seller_order = @payment.order.seller_order
        seller_order.lock!
        new_refunded_amount = @payment.refunded_amount_cents + refund.amount_cents
        new_fee_refunded = @payment.application_fee_refunded_cents + refund.application_fee_amount_cents
        fully_refunded = new_refunded_amount == @payment.amount_cents

        refund.update!(external_id: intent.external_id, status: "approved")
        @payment.update!(
          status: fully_refunded ? "refunded" : "partially_refunded",
          refunded_amount_cents: new_refunded_amount,
          application_fee_refunded_cents: new_fee_refunded
        )
        seller_order.update!(
          status: fully_refunded ? "refunded" : "partially_refunded",
          refunded_amount_cents: new_refunded_amount,
          platform_fee_refunded_cents: new_fee_refunded
        )
        fully_refunded ? @payment.order.mark_refunded! : @payment.order.mark_partially_refunded!

        refund
      end
    end
  end
end
