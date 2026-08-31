module Payments
  # Cria (ou reaproveita) o pagamento de um pedido. Idempotente em relação ao
  # pedido: uma tentativa de pagamento repetida não gera múltiplas cobranças
  # (ver docs/payments.md, "Idempotência") — mas uma tentativa recusada
  # (`failed`) permite uma nova tentativa.
  class Authorize
    def initialize(order:, gateway: Gateways.build)
      @order = order
      @gateway = gateway
    end

    def call
      existing = @order.payments.where(status: %w[pending authorized paid]).order(:created_at).last
      return existing if existing

      intent = @gateway.authorize(order: @order)

      @order.payments.create!(
        gateway: @gateway.name,
        external_id: intent.external_id,
        status: "pending",
        amount_cents: @order.total_cents,
        # Só preenchido em meios de pagamento com QR (PIX). O domínio guarda o
        # código porque o cliente precisa vê-lo de novo ao recarregar a página,
        # e refazer a cobrança no gateway a cada visita geraria cobranças
        # duplicadas.
        pix_qr_code: intent.qr_code,
        pix_qr_code_base64: intent.qr_code_base64,
        expires_at: intent.expires_at
      )
    end
  end
end
