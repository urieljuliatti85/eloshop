class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :product_id, uniqueness: { scope: %i[cart_id product_variant_id] }
  validates :quantity, numericality: { greater_than: 0 }

  validate :variant_required_or_forbidden
  validate :variant_belongs_to_product
  validate :product_available_for_requested_quantity

  def unit_price_cents
    product_variant&.price_cents || product.price_cents
  end

  def subtotal_cents
    quantity * unit_price_cents
  end

  private

  def variant_required_or_forbidden
    return if product.blank?

    if product.has_variants? && product_variant.blank?
      errors.add(:product_variant, "deve ser escolhida para este produto")
    elsif !product.has_variants? && product_variant.present?
      errors.add(:product_variant, "não se aplica a este produto")
    end
  end

  def variant_belongs_to_product
    return if product_variant.blank? || product.blank?
    return if product_variant.product_id == product.id

    errors.add(:product_variant, "não pertence a este produto")
  end

  def product_available_for_requested_quantity
    return if product.blank?

    if product_variant.present?
      validate_variant_quantity
    else
      validate_product_quantity
    end
  end

  def validate_variant_quantity
    unless product_variant.available_for_purchase?
      errors.add(:product_variant, "não está disponível para compra")
      return
    end

    if quantity.to_i > product_variant.stock_quantity
      errors.add(:quantity, "não pode ser maior que o estoque disponível")
    end
  end

  def validate_product_quantity
    unless product.available_for_purchase?
      errors.add(:product, "não está disponível para compra")
      return
    end

    return if product.availability_type_made_to_order?

    if quantity.to_i > product.stock_quantity
      errors.add(:quantity, "não pode ser maior que o estoque disponível")
    end
  end
end
