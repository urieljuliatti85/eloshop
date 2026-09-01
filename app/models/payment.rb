class Payment < ApplicationRecord
  before_validation :ensure_idempotency_key, on: :create

  belongs_to :order
  has_many :payment_events, dependent: :destroy

  enum :status, {
    processing: "processing",
    pending: "pending",
    authorized: "authorized",
    paid: "paid",
    failed: "failed"
  }, default: "pending"

  validates :gateway, presence: true
  validates :external_id, presence: true, unless: :processing?
  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  private

  def ensure_idempotency_key
    self.idempotency_key ||= SecureRandom.uuid
  end
end
