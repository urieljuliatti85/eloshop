class Payment < ApplicationRecord
  before_validation :ensure_idempotency_key, on: :create

  belongs_to :order
  has_many :payment_events, dependent: :destroy
  has_many :payment_refunds, dependent: :destroy

  enum :status, {
    processing: "processing",
    pending: "pending",
    authorized: "authorized",
    paid: "paid",
    partially_refunded: "partially_refunded",
    refunded: "refunded",
    failed: "failed"
  }, default: "pending"

  validates :gateway, presence: true
  validates :external_id, presence: true, unless: :processing?
  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :application_fee_cents, :refunded_amount_cents, :application_fee_refunded_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :processor_fee_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :financial_accounting_is_bounded

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def remaining_refundable_cents
    amount_cents - refunded_amount_cents
  end

  private

  def ensure_idempotency_key
    self.idempotency_key ||= SecureRandom.uuid
  end

  def financial_accounting_is_bounded
    errors.add(:application_fee_cents, "não pode superar o pagamento") if application_fee_cents.to_i > amount_cents.to_i
    errors.add(:refunded_amount_cents, "não pode superar o pagamento") if refunded_amount_cents.to_i > amount_cents.to_i
    if application_fee_refunded_cents.to_i > application_fee_cents.to_i
      errors.add(:application_fee_refunded_cents, "não pode superar a comissão")
    end
  end
end
