# Avisa o comprador de que o reembolso foi solicitado (Payments::Refund). Antes
# deste aviso, só o vendedor era notificado, e o comprador tinha de perguntar
# onde estava o dinheiro.
class NotifyCustomerOfRefundJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(payment_refund)
    OrderMailer.refund_processed(payment_refund).deliver_now
  end
end
