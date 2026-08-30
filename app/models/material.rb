class Material < ApplicationRecord
  has_many :product_materials, dependent: :destroy
  has_many :products, through: :product_materials

  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  private

  def normalize_name
    self.name = name.to_s.strip
    self.slug = name.parameterize if slug.blank? && name.present?
  end
end
