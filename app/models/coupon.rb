class Coupon < ApplicationRecord
  include MoneyAttribute

  # `uses_count` muda a cada compra: seria só ruído.
  has_paper_trail ignore: %i[uses_count updated_at]

  money_attribute :amount
  money_attribute :minimum_subtotal

  has_many :orders, dependent: :nullify
  has_many :carts, dependent: :nullify

  enum :discount_type, { percentage: "percentage", fixed: "fixed" }, prefix: true

  # Para qual tipo de vendedor o cupom vale (ADR 007). O desconto sai do
  # repasse de quem vende (ver docs/checkout.md, "Quem paga o cupom"), então um
  # cupom pensado para peça artesanal não alcança pedido de insumo: o padrão,
  # no banco e aqui, é só ateliê.
  enum :seller_kind, { atelier: "atelier", distributor: "distributor" }, prefix: :for, default: "atelier", validate: true

  before_validation :upcase_code

  validates :code, presence: true, uniqueness: true
  validates :percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: :discount_type_percentage?
  validates :percentage, absence: true, if: :discount_type_fixed?
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }, if: :discount_type_fixed?
  validates :amount_cents, absence: true, if: :discount_type_percentage?
  validates :minimum_subtotal_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_uses, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :uses_count, numericality: { greater_than_or_equal_to: 0 }

  # Fonte única de verdade para elegibilidade — ver CLAUDE.md §7 (não
  # espalhar checagens de disponibilidade pela aplicação). `seller` é
  # obrigatório de propósito, mesmo que nil: quem chama precisa dizer de quem é
  # o carrinho, para nenhum caminho novo esquecer o tipo de vendedor.
  def valid_for?(subtotal_cents, seller:)
    active? &&
      applies_to?(seller) &&
      !expired? &&
      !not_started_yet? &&
      !uses_exhausted? &&
      subtotal_cents >= (minimum_subtotal_cents || 0)
  end

  def expired?
    expires_at.present? && expires_at.past?
  end

  def not_started_yet?
    starts_at.present? && starts_at.future?
  end

  # Carrinho vazio ainda não tem vendedor: o cupom é aceito e o tipo volta a
  # ser conferido a cada cálculo do desconto e dentro da trava do checkout.
  def applies_to?(seller)
    seller.nil? || seller.kind == seller_kind
  end

  def uses_exhausted?
    max_uses.present? && uses_count >= max_uses
  end

  # Nunca deixa o desconto ultrapassar o subtotal — evita total negativo.
  def discount_cents_for(subtotal_cents)
    raw = discount_type_percentage? ? (subtotal_cents * percentage / 100.0).round : amount_cents
    [ raw, subtotal_cents ].min
  end

  private

  def upcase_code
    self.code = code.strip.upcase if code.present?
  end
end
