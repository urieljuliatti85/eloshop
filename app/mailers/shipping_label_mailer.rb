# Aviso de etiqueta que precisa de uma pessoa (ShippingLabels::Track): a
# SuperFrete informou postagem ou entrega, mas o envio não pôde avançar —
# por exemplo, o comprador desistiu ou há reembolso em andamento. O pacote já
# está com a transportadora; a equipe e o ateliê decidem o que fazer.
class ShippingLabelMailer < ApplicationMailer
  TEAM_EMAIL = ContactMailer::DESTINATION_EMAIL

  def needs_attention(label, reason, recipient)
    @label = label
    @reason = reason
    @order = label.seller_order.order
    @seller = label.seller_order.seller
    @for_team = recipient == TEAM_EMAIL

    mail(to: recipient, subject: "Pedido ##{@order.id}: a etiqueta foi #{status_word}, mas o pedido não pôde ser atualizado — EloShop")
  end

  private

  def status_word
    @label.delivered_at? ? "entregue" : "postada"
  end
  helper_method :status_word
end
