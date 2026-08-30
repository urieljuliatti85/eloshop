class ProductMaterial < ApplicationRecord
  belongs_to :product
  belongs_to :material

  validates :material_id, uniqueness: { scope: :product_id }
end
