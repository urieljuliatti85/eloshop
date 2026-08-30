class Cart < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :coupon, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :session_token, presence: true, uniqueness: true

  def subtotal_cents
    cart_items.includes(:product, :product_variant).sum(&:subtotal_cents)
  end

  def discount_cents
    return 0 unless coupon&.valid_for?(subtotal_cents)

    coupon.discount_cents_for(subtotal_cents)
  end
end
