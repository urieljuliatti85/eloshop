class ProductTag < ApplicationRecord
  belongs_to :product
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :product_id }
end
