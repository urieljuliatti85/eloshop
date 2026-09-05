class Coupon < ApplicationRecord
  include MoneyAttribute

  money_attribute :amount
  money_attribute :minimum_subtotal

  has_many :orders, dependent: :nullify
  has_many :carts, dependent: :nullify

  enum :discount_type, { percentage: "percentage", fixed: "fixed" }, prefix: true

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
  # espalhar checagens de disponibilidade pela aplicação).
  def valid_for?(subtotal_cents)
    active? &&
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
