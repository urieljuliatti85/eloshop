class OrderMessageMailer < ApplicationMailer
  def notification(message, recipient)
    @message = message
    @order = message.seller_order.order
    @sender_name = message.sent_by_customer? ? @order.customer.name : message.seller_order.seller.name
    @conversation_url = if message.sent_by_customer?
      seller_order_messages_url(@order)
    else
      order_messages_url(@order)
    end

    mail(
      to: recipient,
      subject: "Nova mensagem no pedido ##{@order.id} — EloShop"
    )
  end
end
