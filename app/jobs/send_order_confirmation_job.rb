# Confirmação de compra para o cliente. Disparado quando o pagamento é
# aprovado — nunca na criação do pedido, porque até lá não houve compra.
class SendOrderConfirmationJob < ApplicationJob
  queue_as :default

  # Pedido apagado entre o enfileiramento e a execução não é erro: nada a
  # enviar. Sem isso o job ficaria repetindo até esgotar as tentativas.
  discard_on ActiveJob::DeserializationError

  def perform(order)
    OrderMailer.confirmation(order).deliver_now
  end
end
