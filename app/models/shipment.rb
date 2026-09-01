class Shipment < ApplicationRecord
  belongs_to :seller_order
  delegate :order, to: :seller_order

  enum :status, {
    pending: "pending",
    shipped: "shipped",
    delivered: "delivered",
    returned: "returned"
  }, default: :pending

  validates :carrier, :service, :shipping_cents, :estimated_days, presence: true
  validates :shipping_cents, :estimated_days, numericality: { greater_than_or_equal_to: 0 }
end
