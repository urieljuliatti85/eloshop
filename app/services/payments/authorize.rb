module Payments
  # Cria ou retoma uma tentativa de pagamento. A tentativa é persistida antes
  # da chamada externa para que um timeout possa reutilizar a mesma chave de
  # idempotência sem criar outra cobrança no gateway.
  class Authorize
    def initialize(order:, gateway: Gateways.build, payment_method: "pix", card_token: nil, installments: 1)
      @order = order
      @gateway = gateway
      @payment_method = payment_method
      @card_token = card_token
      @installments = installments
    end

    def call
      payment = prepare_attempt
      return payment unless payment.processing?

      intent = @gateway.authorize(
        order: @order,
        idempotency_key: payment.idempotency_key,
        application_fee_cents: payment.application_fee_cents,
        payment_method: @payment_method,
        card_token: @card_token,
        installments: @installments
      )

      payment.update!(
        external_id: intent.external_id,
        # "pending" mesmo para cartão: intent.status ("approved"/"declined")
        # é vocabulário do gateway, não um valor válido de Payment#status. A
        # transição real para "paid"/"failed" acontece abaixo, via
        # ProcessWebhook — o mesmo caminho que a notificação real do gateway
        # usaria.
        status: "pending",
        # Só preenchido em meios de pagamento com QR (PIX). O domínio guarda o
        # código porque o cliente precisa vê-lo de novo ao recarregar a página,
        # e refazer a cobrança no gateway a cada visita geraria cobranças
        # duplicadas.
        pix_qr_code: intent.qr_code,
        pix_qr_code_base64: intent.qr_code_base64,
        expires_at: intent.expires_at,
        card_last_four: intent.card_last_four,
        card_brand: intent.card_brand
      )

      Rails.event.notify(
        "payment.attempt_created",
        payment_id: payment.id,
        order_id: @order.id,
        gateway: payment.gateway,
        payment_method: payment.payment_method,
        amount_cents: payment.amount_cents,
        expires_at: payment.expires_at&.iso8601
      )

      # Cartão aprova/recusa na própria resposta do authorize, sem esperar
      # webhook — diferente do PIX, que sempre nasce "pending". Reaproveita
      # ProcessWebhook para aplicar o mesmo efeito (confirmar o pedido,
      # registrar o evento) que a notificação real do gateway também vai
      # disparar depois; a idempotência por gateway_event_id absorve a
      # duplicidade sem duplicar efeito.
      if intent.status.in?(%w[approved declined])
        Payments::ProcessWebhook.new(
          event_id: "sync-#{intent.external_id}-#{intent.status}",
          external_id: intent.external_id,
          status: intent.status
        ).call
        payment.reload
      end

      payment
    end

    private

    def prepare_attempt
      @order.with_lock do
        reusable = @order.payments.where(status: %w[authorized paid partially_refunded refunded]).order(:created_at).last
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
          payment_method: @payment_method,
          installments: @installments,
          amount_cents: @order.total_cents,
          application_fee_cents: @order.seller_order.platform_fee_cents,
          idempotency_key: SecureRandom.uuid
        )
      end
    end
  end
end
