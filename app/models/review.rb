class Review < ApplicationRecord
  belongs_to :customer
  belongs_to :product

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected"
  }, default: "pending"

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :comment, presence: true
  validates :customer_id, uniqueness: { scope: :product_id, message: "já avaliou este produto" }
  validates :seller_reply, presence: true, if: :seller_replied_at?

  before_validation :set_verified_purchase, on: :create

  # Só reviews aprovadas aparecem na loja — moderação obrigatória antes de
  # publicar (decisão de negócio), ver docs/domain.md.
  scope :visible, -> { approved }

  def approve!
    update!(status: "approved")
  end

  def reject!
    update!(status: "rejected")
  end

  def replied?
    seller_reply.present?
  end

  # Só a review já aprovada é pública, então só ela pode receber resposta —
  # responder uma pendente/rejeitada exporia comentário e resposta juntos
  # antes de qualquer moderação.
  def reply!(text)
    raise ArgumentError, "só é possível responder uma avaliação aprovada" unless approved?

    update!(seller_reply: text, seller_replied_at: Time.current)
  end

  private

  # "Compra verificada" é calculada, não escolhida pelo cliente — verdadeira
  # quando ele tem algum pedido confirmado contendo este produto. Não há
  # status "entregue" ainda (Fase 6, ciclo de vida mínimo do pedido), por
  # isso o critério é "confirmed" (pagamento aprovado), não "delivered".
  def set_verified_purchase
    return if customer.blank? || product.blank?

    self.verified_purchase = customer.orders.confirmed.joins(:order_items).exists?(order_items: { product_id: product_id })
  end
end
