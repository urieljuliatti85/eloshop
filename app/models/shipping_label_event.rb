# Notificação do webhook de rastreio da SuperFrete (ADR 005). A SuperFrete
# não manda id de evento e recomenda evitar repetição pelo par evento + id do
# pedido: daí o índice único. Só os campos usados são gravados — o corpo cru
# nunca (a etiqueta e a conta do ateliê têm dados pessoais).
class ShippingLabelEvent < ApplicationRecord
  belongs_to :shipping_label

  validates :event, :provider_order_id, :status, presence: true

  # Grava a notificação de uma etiqueta do próprio ateliê e devolve o evento,
  # ou nil quando não há o que processar: corpo inválido, pedido que não é
  # uma etiqueta deste ateliê (o id de outro ateliê não alcança a etiqueta
  # dele) ou notificação repetida.
  def self.record(seller:, body:)
    payload = JSON.parse(body.to_s)
    data = payload["data"] if payload.is_a?(Hash)
    return unless data.is_a?(Hash)

    event = payload["event"].to_s
    provider_order_id = (data["id"].presence || data["order_id"]).to_s
    status = data["status"].to_s
    return if event.blank? || provider_order_id.blank? || status.blank?

    label = ShippingLabel.joins(shipment: :seller_order)
      .where(seller_orders: { seller_id: seller.id })
      .find_by(provider_order_id: provider_order_id)
    return unless label

    create!(shipping_label: label, event: event.truncate(50), provider_order_id: provider_order_id,
      status: status.truncate(30), tracking_code: data["tracking"].to_s.strip.presence&.truncate(40))
  rescue JSON::ParserError
    nil
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
