class Order < ApplicationRecord
  belongs_to :customer
  has_many :order_items, dependent: :destroy

  validates :subtotal_cents, :shipping_cents, :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_address_snapshot, presence: true
  validates :idempotency_key, presence: true, uniqueness: true
end
