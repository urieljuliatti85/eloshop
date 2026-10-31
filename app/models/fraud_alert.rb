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
      explanation: "Vendedor aprovado com o Mercado Pago conectado, mas numa conta de teste ou de origem desconhecida. Uma venda ali não repassaria dinheiro real.",
      auto_resolvable: false
    },
    "self_purchase" => {
      title: "Compra paga com o mesmo e-mail do vendedor",
      explanation: "Pedido pago em que o cliente usa o mesmo e-mail de um usuário do ateliê. Pode ser autocompra para inflar vendas ou avaliações.",
      auto_resolvable: false
    },
    "unshipped_paid_order" => {
      title: "Pedido pago sem envio dentro do prazo",
      explanation: "Pedido pago há mais de 7 dias (mais o prazo de produção, se sob encomenda) sem envio marcado. Fecha sozinho quando o envio é marcado.",
      auto_resolvable: true
    },
    "shipped_without_tracking" => {
      title: "Envio marcado sem código de rastreio",
      explanation: "Envio marcado há mais de 7 dias sem código de rastreio (retirada local fica de fora). Fecha sozinho quando o código é informado.",
      auto_resolvable: true
    },
    "chargeback" => {
      title: "Chargeback em pedido do ateliê",
      explanation: "O comprador contestou a cobrança no cartão e o Mercado Pago avisou. O pedido e o repasse não mudam sozinhos: quem arca com o valor é decisão sua. Só o admin fecha.",
      auto_resolvable: false
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

  def explanation
    RULES.fetch(rule).fetch(:explanation)
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
