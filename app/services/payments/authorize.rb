module Payments
  # Cria ou retoma uma tentativa de pagamento. A tentativa é persistida antes
  # da chamada externa para que um timeout possa reutilizar a mesma chave de
  # idempotência sem criar outra cobrança no gateway.
  class Authorize
    def initialize(order:, gateway: Gateways.build)
      @order = order
      @gateway = gateway
    end

    def call
      payment = prepare_attempt
      return payment unless payment.processing?

      intent = @gateway.authorize(order: @order, idempotency_key: payment.idempotency_key)

      payment.update!(
        external_id: intent.external_id,
        status: "pending",
        # Só preenchido em meios de pagamento com QR (PIX). O domínio guarda o
        # código porque o cliente precisa vê-lo de novo ao recarregar a página,
        # e refazer a cobrança no gateway a cada visita geraria cobranças
        # duplicadas.
        pix_qr_code: intent.qr_code,
        pix_qr_code_base64: intent.qr_code_base64,
        expires_at: intent.expires_at
      )

      Rails.event.notify(
        "payment.attempt_created",
        payment_id: payment.id,
        order_id: @order.id,
        gateway: payment.gateway,
        amount_cents: payment.amount_cents,
        expires_at: payment.expires_at&.iso8601
      )

      payment
    end

    private

    def prepare_attempt
      @order.with_lock do
        reusable = @order.payments.where(status: %w[authorized paid]).order(:created_at).last
        return reusable if reusable

        pending = @order.payments.pending.order(:created_at).last
        if pending && !pending.expired?
          return pending
        elsif pending
          pending.update!(status: "failed")
        end

        processing = @order.payments.processing.find_by(gateway: @gateway.name)
        return processing if processing

        @order.payments.create!(
          gateway: @gateway.name,
          status: "processing",
          amount_cents: @order.total_cents,
          idempotency_key: SecureRandom.uuid
        )
      end
    end
  end
end
