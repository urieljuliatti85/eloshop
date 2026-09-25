# Trilha técnica de um pedido, para o admin investigar "até onde a compra
# chegou e onde deu erro" (docs/payments.md). Complementa, sem substituir,
# o payload bruto de `PaymentEvent` e os eventos estruturados de
# `Rails.event.notify` (Sentry) — este é o que fica consultável por pedido
# na tela do admin.
class OrderEvent < ApplicationRecord
  belongs_to :order

  enum :kind, {
    order_created: "order_created",
    payment_attempt_created: "payment_attempt_created",
    payment_authorize_failed: "payment_authorize_failed",
    webhook_applied: "webhook_applied",
    order_confirmed: "order_confirmed",
    order_cancelled: "order_cancelled",
    refund_processed: "refund_processed"
  }

  validates :kind, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  def failure?
    error_class.present?
  end
end
