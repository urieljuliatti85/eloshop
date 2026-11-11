# Confere na SuperFrete as etiquetas compradas que ainda não chegaram. O guia
# de webhooks dela avisa que uma notificação que falhou pode não ser
# reenviada e recomenda consultar os pedidos em aberto: esta é a rede de
# segurança do webhook, e passa pelo mesmo ShippingLabels::Track.
#
# Também registra o webhook de quem tem etiqueta em trânsito e ainda não tem.
class ReconcileShippingLabelsJob < ApplicationJob
  queue_as :default

  # Depois disso, quem ainda não chegou é caso para uma pessoa olhar.
  WINDOW = 60.days

  def perform
    return unless ShippingLabels.enabled?

    without_webhook = Set.new
    pending_labels.find_each do |label|
      seller = label.seller_order.seller
      next unless seller.superfrete_ready? && seller.superfrete_account_id == label.superfrete_account_id

      info = ShippingLabels.client_for(seller).order_info(label.provider_order_id)
      ShippingLabels::Track.new(label).apply(status: info.status, tracking: info.tracking)
      without_webhook << seller unless seller.superfrete_webhook_registered?
    rescue ShippingLabels::Client::Error => e
      Rails.event.notify("shipping.label_reconcile_failed", shipping_label_id: label.id, error: e.class.name.demodulize)
    end

    without_webhook.each { |seller| RegisterSuperfreteWebhookJob.perform_later(seller) }
  end

  private

  def pending_labels
    ShippingLabel.purchased
      .where(delivered_at: nil, purchased_at: WINDOW.ago..)
      .joins(:shipment).where.not(shipments: { status: %w[delivered returned] })
      .includes(shipment: { seller_order: :seller })
  end
end
