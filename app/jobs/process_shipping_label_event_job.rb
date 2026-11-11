# Processa uma notificação do webhook de rastreio da SuperFrete fora da
# requisição: a SuperFrete espera resposta em até 10 segundos.
class ProcessShippingLabelEventJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(event)
    return if event.processed_at?

    ShippingLabels::Track.new(event.shipping_label).apply(status: event.status, tracking: event.tracking_code)
    event.update!(processed_at: Time.current)
  end
end
