class ProductVariant < ApplicationRecord
  belongs_to :product

  validates :sku, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: %i[size color material] }
  validate :at_least_one_axis_present
  validate :product_supports_variants

  # Uma variante é a fonte de verdade do estoque quando o produto a possui.
  # Estes escopos alimentam alertas operacionais sem usar o stock_quantity
  # (frequentemente zero) do produto-pai.
  scope :inventory_tracked, -> {
    joins(:product)
      .merge(Product.active.availability_type_standard)
      .where(product_variants: { active: true })
  }
  scope :low_stock, -> { inventory_tracked.where(stock_quantity: 1..Product::LOW_STOCK_THRESHOLD) }
  scope :out_of_stock, -> { inventory_tracked.where(stock_quantity: 0) }

  def available_for_purchase?
    active? && stock_quantity.positive?
  end

  def to_label
    [ size, color, material ].compact_blank.join(" / ")
  end

  private

  def at_least_one_axis_present
    return if size.present? || color.present? || material.present?

    errors.add(:base, "deve informar ao menos um entre tamanho, cor ou material")
  end

  def product_supports_variants
    return if product.blank? || product.availability_type_standard?

    errors.add(:product, "só pode ter variantes quando o tipo de disponibilidade é padrão (estoque)")
  end
end
