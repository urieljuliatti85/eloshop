module ShippingLabels
  # Aplica à etiqueta e ao envio o que a SuperFrete informou, pelo webhook
  # (ProcessShippingLabelEventJob) ou pela conferência periódica
  # (ReconcileShippingLabelsJob) — os dois caminhos passam por aqui.
  #
  # Regras do guia de webhooks da SuperFrete: os eventos podem chegar fora de
  # ordem ou pular etapas, então vale o status informado, não a ordem de
  # chegada; `order.posted` nem é enviado se o pacote já foi entregue. Por
  # isso "entregue" também marca o envio como enviado antes.
  #
  # Decisões do Uriel (2026-11-11):
  # * a entrega confirmada pela transportadora fecha o envio como entregue
  #   (é prova, diferente do clique do comprador), com aviso próprio;
  # * se o envio não pode avançar (desistência aberta, reembolso integral em
  #   andamento, pedido reembolsado), a etiqueta guarda o que a SuperFrete
  #   informou, o envio não muda e a equipe e o ateliê recebem um aviso, uma
  #   vez só: o pacote já está com a transportadora e alguém precisa agir.
  class Track
    PAID_STATUSES = %w[released generated posted delivered].freeze
    PROGRESS = { "released" => 1, "generated" => 2, "posted" => 3, "delivered" => 4 }.freeze

    def initialize(label)
      @label = label
    end

    def apply(status:, tracking: nil)
      status = normalize(status)

      # A compra ainda não foi confirmada do nosso lado: quem decide é a
      # própria compra, conferindo o pedido.
      if @label.purchasing? && PAID_STATUSES.include?(status)
        PurchaseShippingLabelJob.perform_later(@label)
        return :reconciling
      end
      return :ignored unless @label.purchased?

      record(status, tracking)
      case status
      when "posted" then ship
      when "delivered" then ship && deliver
      when "cancelled" then cancel_label
      end
      status.to_sym
    end

    private

    def normalize(status)
      status = status.to_s.downcase
      status == "canceled" ? "cancelled" : status
    end

    def record(status, tracking)
      changes = {}
      changes[:tracking_code] = tracking if @label.tracking_code.blank? && tracking.present?
      if PROGRESS.fetch(status, 0) > PROGRESS.fetch(@label.provider_status.to_s, 0)
        changes[:provider_status] = status
      end
      changes[:posted_at] = Time.current if %w[posted delivered].include?(status) && @label.posted_at.nil?
      changes[:delivered_at] = Time.current if status == "delivered" && @label.delivered_at.nil?
      @label.update!(changes) if changes.any?
    end

    # Devolve true quando o envio está (ou ficou) enviado.
    def ship
      shipment = @label.shipment.reload
      return true unless shipment.pending?

      mark_shipped(shipment)
      ShipmentNotifications.shipped(shipment)
      true
    rescue Shipment::InvalidStatusTransition => e
      # Outro caminho (o ateliê no painel, ou o webhook e a conferência ao
      # mesmo tempo) chegou antes.
      return true unless shipment.reload.pending?

      needs_attention(e.message)
      false
    end

    # O código já pode estar em outro envio (o ateliê colou o mesmo código em
    # outro pedido): o envio avança sem ele, e o ateliê corrige no painel.
    def mark_shipped(shipment)
      shipment.mark_shipped!(service: @label.service_name, tracking_code: shipment.tracking_code.presence || @label.tracking_code)
    rescue Shipment::InvalidTrackingCode
      shipment.mark_shipped!(service: @label.service_name, tracking_code: shipment.tracking_code.presence)
    end

    def deliver
      shipment = @label.shipment.reload
      return unless shipment.shipped?

      shipment.mark_delivered!
      ShipmentNotifications.delivered(shipment, by_carrier: true)
    rescue Shipment::InvalidStatusTransition => e
      needs_attention(e.message) unless shipment.reload.delivered?
    end

    # Cancelada do lado da SuperFrete (pelo site dela) antes da postagem.
    def cancel_label
      return unless @label.shipment.pending?

      @label.advance!(from: :purchased, to: :cancelled, cancelled_at: Time.current)
    end

    def needs_attention(reason)
      claimed = ShippingLabel.where(id: @label.id, attention_notified_at: nil).update_all(attention_notified_at: Time.current)
      return if claimed.zero?

      Rails.event.notify("shipping.label_needs_attention", shipping_label_id: @label.id, seller_id: @label.seller_order.seller_id)
      NotifyShippingLabelAttentionJob.perform_later(@label, reason)
    end
  end
end
