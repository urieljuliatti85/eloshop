class Cart < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :session_token, presence: true, uniqueness: true

  def subtotal_cents
    cart_items.includes(:product).sum(&:subtotal_cents)
  end
end
