class SellerOrder < ApplicationRecord
  PLATFORM_FEE_RATE_BPS = 1_500
  BASIS_POINTS = 10_000
  MESSAGEABLE_STATUSES = %w[confirmed partially_refunded refunded].freeze

  belongs_to :order
  belongs_to :seller
  has_many :order_items, dependent: :restrict_with_error
  has_many :order_messages, dependent: :destroy
  has_one :shipment, dependent: :destroy

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled",
    partially_refunded: "partially_refunded",
    refunded: "refunded"
  }, default: :pending

  validates :currency, presence: true
  validates :platform_fee_rate_bps, numericality: { only_integer: true, in: 0..BASIS_POINTS }
  validates :subtotal_cents, :discount_cents, :shipping_cents, :total_cents,
    :platform_fee_cents, :seller_amount_cents, :refunded_amount_cents,
    :platform_fee_refunded_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :seller_id, uniqueness: { scope: :order_id }
  validate :financial_snapshot_is_consistent
  validate :refund_accounting_is_bounded

  def self.platform_fee_cents_for(subtotal_cents:, discount_cents:, rate_bps: PLATFORM_FEE_RATE_BPS)
    commission_base_cents = [ subtotal_cents - discount_cents, 0 ].max
    numerator = commission_base_cents * rate_bps
    quotient, remainder = numerator.divmod(BASIS_POINTS)
    quotient + (remainder >= BASIS_POINTS / 2 ? 1 : 0)
  end

  def commission_base_cents
    subtotal_cents - discount_cents
  end

  def remaining_refundable_cents
    total_cents - refunded_amount_cents
  end

  class ProductionNotApplicable < StandardError; end

  # Peça sob encomenda (tem prazo de produção no snapshot) ou personalizada
  # (tem escolhas do cliente). Peça pronta não tem "início de produção".
  def custom_work?
    order_items.any? { |item| item.production_time_snapshot.present? || item.personalizations.any? }
  end

  # O marco só faz sentido enquanto há o que marcar: pagamento confirmado,
  # ainda não iniciado, ainda não enviado.
  def production_start_applicable?
    confirmed? && production_started_at.nil? && custom_work? && (shipment.nil? || shipment.pending?)
  end

  def production_started?
    production_started_at.present?
  end

  # Irreversível de propósito: o marco serve de prova numa disputa, então o
  # vendedor não pode desfazê-lo para reabrir ou fechar o direito do comprador.
  def start_production!
    with_lock do
      raise ProductionNotApplicable, "este pedido não permite marcar o início da produção" unless production_start_applicable?

      update!(production_started_at: Time.current)
    end
    OrderEvent.create!(order: order, kind: :production_started, status: order.status)
  end

  # Enviar implica que a produção já aconteceu: preenche o marco se o vendedor
  # não o marcou, sem sobrescrever uma marcação anterior.
  def record_production_start_from_shipping!
    return unless custom_work? && production_started_at.nil?

    update!(production_started_at: Time.current)
    OrderEvent.create!(order: order, kind: :production_started, status: order.status)
  end

  # A conversa nasce apenas quando a compra existe de fato. Reembolsos não
  # apagam o canal: comprador e artesão ainda podem precisar combinar
  # devolução, retirada ou esclarecer o que aconteceu.
  def accepts_messages?
    status.in?(MESSAGEABLE_STATUSES)
  end

  def platform_fee_refund_for(amount_cents, reserved_amount_cents: 0, reserved_fee_cents: 0)
    return 0 if platform_fee_cents.zero? || amount_cents.zero?
    if amount_cents + reserved_amount_cents == remaining_refundable_cents
      return platform_fee_cents - platform_fee_refunded_cents - reserved_fee_cents
    end

    cumulative_refund = refunded_amount_cents + reserved_amount_cents + amount_cents
    target_fee_refund = proportional_amount(platform_fee_cents, cumulative_refund, total_cents)

    available_fee = platform_fee_cents - platform_fee_refunded_cents - reserved_fee_cents
    (target_fee_refund - platform_fee_refunded_cents - reserved_fee_cents).clamp(0, available_fee)
  end

  private

  def proportional_amount(amount, numerator, denominator)
    quotient, remainder = (amount * numerator).divmod(denominator)
    quotient + (remainder * 2 >= denominator ? 1 : 0)
  end

  def financial_snapshot_is_consistent
    errors.add(:discount_cents, "não pode superar o subtotal") if discount_cents.to_i > subtotal_cents.to_i
    errors.add(:total_cents, "não corresponde ao subtotal, desconto e frete") if total_cents.to_i != subtotal_cents.to_i - discount_cents.to_i + shipping_cents.to_i
    errors.add(:platform_fee_cents, "não corresponde à taxa registrada") if platform_fee_cents.to_i != self.class.platform_fee_cents_for(subtotal_cents: subtotal_cents.to_i, discount_cents: discount_cents.to_i, rate_bps: platform_fee_rate_bps.to_i)
    errors.add(:seller_amount_cents, "não corresponde ao total após a comissão") if seller_amount_cents.to_i != total_cents.to_i - platform_fee_cents.to_i
  end

  def refund_accounting_is_bounded
    errors.add(:refunded_amount_cents, "não pode superar o total") if refunded_amount_cents.to_i > total_cents.to_i
    if platform_fee_refunded_cents.to_i > platform_fee_cents.to_i
      errors.add(:platform_fee_refunded_cents, "não pode superar a comissão")
    end
  end
end
