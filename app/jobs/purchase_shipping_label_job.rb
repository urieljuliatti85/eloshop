# Compra a etiqueta fora da requisição do painel (ShippingLabels::Purchase):
# a SuperFrete pode levar segundos, e o Puma tem poucas threads.
#
# Repete só o que é incerto (Purchase::Retry), com espera: o pagamento nunca é
# reenviado depois de um resultado incerto, então repetir aqui é conferir o
# pedido na SuperFrete. Esgotadas as tentativas, a etiqueta fica em
# "confirmando" e o ateliê pode conferir de novo ou cancelar pelo painel.
class PurchaseShippingLabelJob < ApplicationJob
  queue_as :default

  retry_on ShippingLabels::Purchase::Retry, wait: 1.minute, attempts: 5 do |job, error|
    Rails.event.notify("shipping.label_unconfirmed", shipping_label_id: job.arguments.first&.id, error: error.message)
  end
  discard_on ActiveJob::DeserializationError

  def perform(label)
    ShippingLabels::Purchase.new(label).call
  end
end
