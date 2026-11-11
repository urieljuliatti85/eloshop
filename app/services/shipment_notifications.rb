# Avisos ao comprador quando o envio muda de estado. Um lugar só para os dois
# caminhos: o ateliê marcando no painel (SellerPortal::OrdersController) e a
# SuperFrete informando pelo rastreio (ShippingLabels::Track). Chamar só
# depois de a transição acontecer de fato, para não repetir aviso.
module ShipmentNotifications
  extend self

  def shipped(shipment)
    order = shipment.order
    NotifyCustomerOfShipmentJob.perform_later(shipment.seller_order)
    Notification.create!(
      recipient: order.customer,
      kind: :order_shipped,
      title: shipment.local_pickup? ? "Pedido pronto para retirada" : "Pedido enviado",
      body: shipment.local_pickup? ? "Seu pedido ##{order.id} está pronto para retirada." : "Seu pedido ##{order.id} foi enviado.",
      url: routes.order_path(order)
    )
  end

  # `by_carrier`: a entrega veio do rastreio da transportadora, não do clique
  # do ateliê — o aviso diz quem confirmou.
  def delivered(shipment, by_carrier: false)
    order = shipment.order
    if by_carrier
      NotifyCustomerOfDeliveryJob.perform_later(shipment.seller_order, by_carrier: true)
    else
      NotifyCustomerOfDeliveryJob.perform_later(shipment.seller_order)
    end
    Notification.create!(
      recipient: order.customer,
      kind: :order_delivered,
      title: "Pedido entregue",
      body: by_carrier ? "A transportadora confirmou a entrega do seu pedido ##{order.id}." : "O vendedor confirmou a entrega do seu pedido ##{order.id}.",
      url: routes.order_path(order)
    )
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end
end
