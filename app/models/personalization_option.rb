class PersonalizationOption < ApplicationRecord
  belongs_to :product

  validates :label, presence: true, uniqueness: { scope: :product_id }
  validates :max_length, numericality: { greater_than: 0 }
end
