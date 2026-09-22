# Entrega uma cópia da nova mensagem ao outro lado do pedido. O job recebe
# apenas o registro, nunca o texto como argumento, para não expor a conversa
# nos argumentos serializados da fila.
class NotifyOrderMessageJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(message)
    recipients_for(message).each do |recipient|
      OrderMessageMailer.notification(message, recipient).deliver_now
    end
  end

  private

  def recipients_for(message)
    if message.sent_by_customer?
      message.seller_order.seller.users.seller.order(:created_at).pluck(:email_address)
    else
      [ message.seller_order.order.customer.email ]
    end
  end
end
