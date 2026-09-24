# Avisa o artesão de que o comprador reportou o recebimento — sinal do
# cliente, não fechamento oficial da entrega (ver
# Shipment#report_delivered_by_customer!).
class NotifySellerOfDeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller_order)
    recipient = recipient_for(seller_order.seller)

    # Ateliê sem usuário vinculado não tem para onde receber. Não é erro —
    # o pedido continua visível no painel; um retry não criaria o e-mail.
    return if recipient.blank?

    OrderMailer.delivery_reported_by_customer(seller_order, recipient).deliver_now
  end

  private

  def recipient_for(seller)
    seller.users.order(:created_at).first&.email_address
  end
end
