class WishlistItem < ApplicationRecord
  belongs_to :customer
  belongs_to :product

  validates :product_id, uniqueness: { scope: :customer_id }
end
