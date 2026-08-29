class Order < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[confirmed cancelled],
    "confirmed" => %w[cancelled],
    "cancelled" => []
  }.freeze

  belongs_to :customer
  has_many :order_items, dependent: :destroy

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled"
  }, default: "pending"

  validates :subtotal_cents, :shipping_cents, :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_address_snapshot, presence: true
  validates :idempotency_key, presence: true, uniqueness: true

  def confirm!
    transition_to!("confirmed")
  end

  def cancel!
    transition_to!("cancelled")
  end

  private

  def transition_to!(new_status)
    unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(new_status)
      raise InvalidStatusTransition, "não é possível transicionar de #{status} para #{new_status}"
    end

    update!(status: new_status)
  end
end
