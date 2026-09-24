# Avisa o cliente de que o vendedor confirmou a entrega oficialmente
# (Shipment#mark_delivered!) — aviso inverso de NotifySellerOfDeliveryJob,
# que só carrega o sinal (não oficial) do cliente. Recebe o SellerOrder pelo
# mesmo motivo do job de nova venda: quando o split 1:N for liberado, o
# fan-out não precisa reescrita.
class NotifyCustomerOfDeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller_order)
    OrderMailer.delivery_confirmed_by_seller(seller_order).deliver_now
  end
end
