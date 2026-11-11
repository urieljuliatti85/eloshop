# Registra (ou troca) o webhook de rastreio na conta SuperFrete do ateliê
# (ShippingLabels::Webhook). Enfileirado ao conectar a SuperFrete e depois da
# compra de uma etiqueta, se o ateliê ainda não tiver webhook. Um por ateliê
# por vez, para não criar dois webhooks na mesma conta.
class RegisterSuperfreteWebhookJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(seller) { seller }

  retry_on ShippingLabels::Client::Ambiguous, wait: 5.minutes, attempts: 3 do |job, error|
    Rails.event.notify("shipping.webhook_register_failed", seller_id: job.arguments.first&.id, error: error.message)
  end
  discard_on ActiveJob::DeserializationError

  def perform(seller)
    ShippingLabels::Webhook.new(seller).register
  rescue ShippingLabels::Client::Rejected => e
    # Recusado (token revogado, por exemplo): repetir não muda. A conferência
    # periódica segue acompanhando as etiquetas sem o webhook.
    Rails.event.notify("shipping.webhook_register_failed", seller_id: seller.id, error: e.message)
  end
end
