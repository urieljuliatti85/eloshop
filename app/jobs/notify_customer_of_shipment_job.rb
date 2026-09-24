# Avisa o cliente de que o vendedor despachou o pedido
# (Shipment#mark_shipped!) — aviso anterior a NotifyCustomerOfDeliveryJob,
# que só dispara quando a entrega é confirmada oficialmente.
class NotifyCustomerOfShipmentJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller_order)
    OrderMailer.shipped(seller_order).deliver_now
  end
end
