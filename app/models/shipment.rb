class Shipment < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[shipped],
    "shipped" => %w[delivered],
    "delivered" => [],
    "returned" => []
  }.freeze

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

  def local_pickup?
    service == Shipping::Quote::LOCAL_PICKUP_SERVICE
  end

  def mark_shipped!
    transition_to!("shipped", shipped_at: Time.current)
  end

  def mark_delivered!
    transition_to!("delivered", delivered_at: Time.current)
  end

  private

  def transition_to!(new_status, timestamp)
    with_lock do
      unless seller_order.confirmed? || seller_order.partially_refunded?
        raise InvalidStatusTransition, "o pagamento precisa estar confirmado antes de atualizar a entrega"
      end

      unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(new_status)
        raise InvalidStatusTransition, "não é possível transicionar a entrega de #{status} para #{new_status}"
      end

      update!(status: new_status, **timestamp)
    end
  end
end
