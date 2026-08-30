class ProductTechnique < ApplicationRecord
  belongs_to :product
  belongs_to :technique

  validates :technique_id, uniqueness: { scope: :product_id }
end
