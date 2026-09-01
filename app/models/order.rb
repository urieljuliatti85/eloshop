class Order < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[confirmed cancelled],
    "confirmed" => %w[cancelled partially_refunded refunded],
    "partially_refunded" => %w[refunded],
    "cancelled" => [],
    "refunded" => []
  }.freeze

  belongs_to :customer
  belongs_to :coupon, optional: true
  has_many :order_items, dependent: :destroy
  has_many :seller_orders, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :shipments, through: :seller_orders

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled",
    partially_refunded: "partially_refunded",
    refunded: "refunded"
  }, default: "pending"

  validates :subtotal_cents, :shipping_cents, :total_cents, :discount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_address_snapshot, presence: true
  validates :idempotency_key, presence: true, uniqueness: true

  def confirm!
    transition_to!("confirmed")
  end

  def cancel!
    transition_to!("cancelled")
  end

  def mark_partially_refunded!
    transition_to!("partially_refunded")
  end

  def mark_refunded!
    transition_to!("refunded")
  end

  def seller_order
    seller_orders.sole
  end

  def shipment
    seller_orders.first&.shipment
  end

  private

  def transition_to!(new_status)
    unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(new_status)
      raise InvalidStatusTransition, "não é possível transicionar de #{status} para #{new_status}"
    end

    transaction do
      update!(status: new_status)
      seller_orders.where(status: status_before_last_save).update_all(status: new_status, updated_at: Time.current)
    end
  end
end
