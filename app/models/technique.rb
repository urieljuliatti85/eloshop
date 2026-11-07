class Technique < ApplicationRecord
  enum :icon_type, {
    yarn: "yarn",
    fabric: "fabric",
    ribbon: "ribbon",
    notions: "notions",
    wood: "wood",
    clay: "clay",
    needlework: "needlework",
    knotting: "knotting",
    paint: "paint",
    other: "other"
  }, default: "other", prefix: :category_icon

  has_many :product_techniques, dependent: :destroy
  has_many :products, through: :product_techniques

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
    when /croche/ then :yarn
    when /bordado|costura/ then :needlework
    when /marcenaria|entalhe/ then :wood
    when /macrame/ then :knotting
    when /pintura|aquarela/ then :paint
    when /ceramica|argila/ then :clay
    else :other
    end
  end
end
