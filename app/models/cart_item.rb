class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  validates :product_id, uniqueness: { scope: :cart_id }
  validates :quantity, numericality: { greater_than: 0 }

  validate :product_available_for_requested_quantity

  def subtotal_cents
    quantity * product.price_cents
  end

  private

  def product_available_for_requested_quantity
    return if product.blank?

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
