class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :product_name, :sku, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  def subtotal_cents
    unit_price_cents * quantity
  end
end
