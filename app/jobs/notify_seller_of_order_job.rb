# Avisa o artesão de que vendeu. Um pedido tem um `SellerOrder` só (o
# checkout aceita um vendedor por vez — ver CLAUDE.md §34), mas o job recebe
# o `SellerOrder` e não o `Order` de propósito: quando o split 1:N for
# liberado, o fan-out passa a enfileirar um job por vendedor sem reescrita.
class NotifySellerOfOrderJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller_order)
    recipient = recipient_for(seller_order.seller)

    # Ateliê sem usuário vinculado não tem para onde receber. Não é erro —
    # o pedido continua visível no painel; um retry não criaria o e-mail.
    return if recipient.blank?

    OrderMailer.seller_notification(seller_order, recipient).deliver_now
  end

  private

  def recipient_for(seller)
    seller.users.order(:created_at).first&.email_address
  end
end
