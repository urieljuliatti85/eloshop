class Payment < ApplicationRecord
  belongs_to :order
  has_many :payment_events, dependent: :destroy

  enum :status, {
    pending: "pending",
    authorized: "authorized",
    paid: "paid",
    failed: "failed"
  }, default: "pending"

  validates :gateway, presence: true
  validates :external_id, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
end
