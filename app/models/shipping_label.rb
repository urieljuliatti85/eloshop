# Etiqueta da SuperFrete comprada pelo ateliê para um envio (ADR 005, "Etapa
# 2 e 3"). A compra debita a carteira do ateliê e a SuperFrete não oferece
# idempotência, por isso os estados são explícitos:
#
#   draft → cart_created → purchasing → purchased → cancelled
#
# Todo estado ativo pode ir para `cancelled` (clique do ateliê); `draft`,
# `cart_created` e `purchasing` também para `failed`.
#
# * `draft`: pedida no painel, ainda sem nada na SuperFrete.
# * `cart_created`: o pedido existe lá (`provider_order_id` gravado), sem
#   cobrança.
# * `purchasing`: o pagamento foi enviado. Se a resposta se perder, só a
#   consulta do pedido na SuperFrete diz se foi cobrado
#   (ShippingLabels::Purchase#reconcile) — nunca se cria outro pedido.
# * `purchased`: paga; o PDF é pedido na hora de imprimir, não guardado.
# * `cancelled` / `failed`: liberam o envio para uma nova etiqueta.
class ShippingLabel < ApplicationRecord
  class InvalidTransition < StandardError; end

  ACTIVE_STATUSES = %w[draft cart_created purchasing purchased].freeze

  TRANSITIONS = {
    "draft" => %w[cart_created failed cancelled],
    "cart_created" => %w[purchasing cancelled failed],
    "purchasing" => %w[purchased cart_created failed cancelled],
    "purchased" => %w[cancelled],
    "cancelled" => [],
    "failed" => []
  }.freeze

  belongs_to :shipment
  has_many :events, class_name: "ShippingLabelEvent", dependent: :destroy

  enum :status, {
    draft: "draft",
    cart_created: "cart_created",
    purchasing: "purchasing",
    purchased: "purchased",
    cancelled: "cancelled",
    failed: "failed"
  }, default: "draft"

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  validates :service_code, :service_name, :quoted_price_cents, :superfrete_account_id, presence: true
  validates :height_cm, :width_cm, :length_cm, :weight_grams, numericality: { only_integer: true, greater_than: 0 }
  validates :sandbox, inclusion: { in: [ true, false ] }

  delegate :seller_order, to: :shipment

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  # Ainda em andamento do nosso lado: o painel mostra "gerando" e não deixa
  # pedir outra.
  def in_progress?
    draft? || cart_created? || purchasing?
  end

  # A compra foi recusada por falta de saldo na carteira. A SuperFrete não
  # manda código de erro, só o texto ("Sem saldo na carteira! Utilize o app
  # para recarregar a carteira ou pagar a etiqueta com cartão de crédito.",
  # visto no sandbox em 2026-11-05 e 2026-11-11): o painel usa isto para
  # explicar que, pela EloShop, a etiqueta sai sempre do saldo — o cartão de
  # crédito da mensagem só existe no app dela.
  def failed_for_lack_of_balance?
    failed? && failure_message.to_s.match?(/sem saldo/i)
  end

  # Muda o estado só se ele ainda for `from` (UPDATE condicionado): dois jobs
  # ou um job e um clique não avançam a mesma etiqueta duas vezes. Devolve
  # false quando outro processo chegou antes.
  def advance!(from:, to:, **attributes)
    from = Array(from).map(&:to_s)
    raise InvalidTransition, "#{from.join('/')} → #{to}" unless from.all? { |state| TRANSITIONS.fetch(state).include?(to.to_s) }

    changes = attributes.merge(status: to.to_s, updated_at: Time.current)
    updated = self.class.where(id: id, status: from).update_all(changes)
    reload if updated.positive?
    updated.positive?
  end
end
