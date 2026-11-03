class PaymentRefund < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]
  belongs_to :payment
  belongs_to :recorded_by, class_name: "User", optional: true

  # `gateway`: devolvido pelo Mercado Pago. `manual`: devolvido por fora dele
  # (transferência ou PIX direto ao comprador) quando o provedor não consegue —
  # ateliê sem saldo no split 1:1 ou pagamento com mais de 180 dias.
  enum :settlement, { gateway: "gateway", manual: "manual" }, default: :gateway, prefix: :settled_by

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
  validates :recorded_by, :manual_reference, presence: true, if: :settled_by_manual?
  validates :manual_reference, length: { in: 3..500 }, allow_blank: true

  private

  def application_fee_does_not_exceed_refund
    return unless application_fee_amount_cents.to_i > amount_cents.to_i

    errors.add(:application_fee_amount_cents, "não pode superar o reembolso")
  end
end
