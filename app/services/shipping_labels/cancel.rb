module ShippingLabels
  # Cancelamento pedido pelo ateliê, com um clique: nada cancela etiqueta
  # sozinho (decisão do Uriel de 2026-11-05 — um cancelamento automático por
  # engano faria o artesão perder a postagem). A SuperFrete só cancela antes
  # da postagem e devolve o valor para a carteira do ateliê.
  class Cancel
    REASON = "Cancelado pelo ateliê na EloShop".freeze

    def initialize(label, client: nil)
      @label = label
      @client = client || ShippingLabels.client_for(label.seller_order.seller)
    end

    def call
      raise Refused, "Esta etiqueta não pode mais ser cancelada." unless cancellable?
      raise Refused, "O pedido já foi enviado; a etiqueta não pode mais ser cancelada por aqui." unless @label.shipment.pending?

      status_before = @label.status
      cancel_at_provider if @label.provider_order_id.present?
      @label.advance!(from: status_before, to: :cancelled, cancelled_at: Time.current) ||
        raise(Refused, "A etiqueta mudou enquanto você cancelava. Atualize a página.")
      @label
    end

    private

    # Toda etiqueta ativa: inclusive a presa em `draft` ou `cart_created`
    # quando o job morreu no meio (deploy, erro inesperado), que sem isto
    # bloquearia o pedido para sempre. Nesses dois estados nada foi cobrado.
    def cancellable?
      @label.active?
    end

    def cancel_at_provider
      @client.cancel(@label.provider_order_id, reason: REASON)
    rescue Client::Rejected => e
      # Repetir num pedido já cancelado responde 409: confere pela consulta.
      info = order_info
      raise Refused, "A etiqueta já foi postada e não pode mais ser cancelada." if info&.posted?
      raise Refused, "A SuperFrete não cancelou a etiqueta: #{e.message}" unless info&.cancelled?
    rescue Client::Ambiguous
      raise Refused, "A SuperFrete não respondeu. Tente cancelar de novo em alguns minutos."
    end

    def order_info
      @client.order_info(@label.provider_order_id)
    rescue Client::Error
      nil
    end
  end
end
