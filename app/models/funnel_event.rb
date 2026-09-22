class FunnelEvent < ApplicationRecord
  EVENT_NAMES = %w[
    view_catalog
    view_product
    add_to_cart
    checkout_started
    payment_started
    order_confirmed
    payment_failed
  ].freeze

  belongs_to :product, optional: true
  belongs_to :seller, optional: true

  validates :event_name, inclusion: { in: EVENT_NAMES }
  validates :occurred_on, presence: true
  validates :event_count, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :within, ->(range) { where(occurred_on: range) }
end
