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
