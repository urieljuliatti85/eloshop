class PaymentRefund < ApplicationRecord
  belongs_to :payment

  enum :status, {
    processing: "processing",
    approved: "approved",
    failed: "failed"
  }, default: :processing

  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :application_fee_amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :application_fee_does_not_exceed_refund

  private

  def application_fee_does_not_exceed_refund
    return unless application_fee_amount_cents.to_i > amount_cents.to_i

    errors.add(:application_fee_amount_cents, "não pode superar o reembolso")
  end
end
