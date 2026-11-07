class Material < ApplicationRecord
  enum :icon_type, {
    yarn: "yarn",
    fabric: "fabric",
    ribbon: "ribbon",
    notions: "notions",
    wood: "wood",
    clay: "clay",
    other: "other"
  }, default: "other", prefix: :category_icon

  has_many :product_materials, dependent: :destroy
  has_many :products, through: :product_materials

  before_validation :normalize_name
  before_validation :infer_icon_type

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  private

  def normalize_name
    self.name = name.to_s.strip
    self.slug = name.parameterize if slug.blank? && name.present?
  end

  def infer_icon_type
    return if name.blank? || (icon_type.present? && !category_icon_other?)

    normalized = ActiveSupport::Inflector.transliterate(name).downcase
    self.icon_type = case normalized
    when /fio|linha|algodao|\bla(s)?\b/ then :yarn
    when /tecido|linho|feltro|malha|manta/ then :fabric
    when /fita|renda|galao|cetim|gorgurao/ then :ribbon
    when /aviamento|botao|ziper|agulha|ferragem|micanga|conta/ then :notions
    when /madeira|vime/ then :wood
    when /argila|ceramica/ then :clay
    else :other
    end
  end
end
