# Avisa a equipe e o ateliê de que a SuperFrete informou postagem ou entrega
# de uma etiqueta cujo envio não pôde avançar (ShippingLabels::Track). Um
# aviso por etiqueta: quem enfileira já marcou `attention_notified_at`.
class NotifyShippingLabelAttentionJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(label, reason)
    recipients = [ ShippingLabelMailer::TEAM_EMAIL, label.seller_order.seller.users.order(:created_at).first&.email_address ]
    recipients.compact_blank.uniq.each do |recipient|
      ShippingLabelMailer.needs_attention(label, reason, recipient).deliver_now
    end
  end
end
