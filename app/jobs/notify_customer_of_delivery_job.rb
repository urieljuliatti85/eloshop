# Avisa o cliente de que o vendedor confirmou a entrega oficialmente
# (Shipment#mark_delivered!) — aviso inverso de NotifySellerOfDeliveryJob,
# que só carrega o sinal (não oficial) do cliente. Recebe o SellerOrder pelo
# mesmo motivo do job de nova venda: quando o split 1:N for liberado, o
# fan-out não precisa reescrita.
class NotifyCustomerOfDeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # `by_carrier`: confirmada pelo rastreio da transportadora (ShippingLabels::Track).
  def perform(seller_order, by_carrier: false)
    OrderMailer.delivery_confirmed_by_seller(seller_order, by_carrier: by_carrier).deliver_now
  end
end
