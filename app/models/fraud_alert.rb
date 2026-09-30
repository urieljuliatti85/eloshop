# Sinal de que um vendedor merece uma olhada do admin. Só registra e avisa —
# suspender, reembolsar ou falar com o vendedor continua sendo decisão humana
# (CLAUDE.md §69). Existe no máximo um alerta aberto por vendedor e regra.
class FraudAlert < ApplicationRecord
  # `auto_resolvable`: a regra enxerga sozinha quando o problema acabou (o envio
  # foi marcado). Nas demais, nada no sistema diz que o caso foi resolvido, então
  # só o admin fecha.
  RULES = {
    "unverified_account" => {
      title: "Aprovado com conta do Mercado Pago que não é real",
      auto_resolvable: false
    },
    "self_purchase" => {
      title: "Compra paga com o mesmo e-mail do vendedor",
      auto_resolvable: false
    },
    "unshipped_paid_order" => {
      title: "Pedido pago sem envio dentro do prazo",
      auto_resolvable: true
    },
    "shipped_without_tracking" => {
      title: "Envio marcado sem código de rastreio",
      auto_resolvable: true
    }
  }.freeze

  belongs_to :seller

  validates :rule, inclusion: { in: RULES.keys }
  validates :detected_at, presence: true

  scope :open, -> { where(resolved_at: nil) }
  scope :recent_first, -> { order(detected_at: :desc) }

  def title
    RULES.fetch(rule).fetch(:title)
  end

  def auto_resolvable?
    RULES.fetch(rule).fetch(:auto_resolvable)
  end

  def resolved?
    resolved_at.present?
  end

  def resolve!
    update!(resolved_at: Time.current) unless resolved?
  end
end
