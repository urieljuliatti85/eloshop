class SellerReport < ApplicationRecord
  belongs_to :customer
  belongs_to :seller

  enum :status, {
    pending: "pending",
    reviewing: "reviewing",
    resolved: "resolved",
    dismissed: "dismissed"
  }, default: "pending"

  REASON_LABELS = {
    "fraud" => "Atividade fraudulenta",
    "counterfeit" => "Produto falsificado",
    "no_delivery" => "Pedido não entregue",
    "poor_quality" => "Qualidade muito abaixo do anunciado",
    "other" => "Outro motivo"
  }.freeze

  validates :reason, presence: true, inclusion: { in: REASON_LABELS.keys }

  def reason_label
    REASON_LABELS.fetch(reason, reason)
  end
  validates :details, length: { maximum: 2_000 }
  # Um cliente só tem uma denúncia ativa por ateliê — evita flood do mesmo
  # cliente contra o mesmo vendedor (mitiga junto com o rate limit do
  # controller, que cobre tentativas de clientes diferentes).
  validates :customer_id, uniqueness: { scope: :seller_id, message: "você já denunciou este ateliê" }

  def review!
    update!(status: "reviewing")
  end

  def resolve!
    update!(status: "resolved")
  end

  def dismiss!
    update!(status: "dismissed")
  end
end
