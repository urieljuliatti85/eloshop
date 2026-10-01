class Cart < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :coupon, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :session_token, presence: true, uniqueness: true

  # Itens que ainda vale lembrar o cliente: só os que podem ser comprados
  # agora. Não adianta atrair de volta para algo que já saiu do ar.
  def remindable_items
    cart_items.includes(:product_variant, product: :seller).select do |item|
      item.product.available_for_purchase? && (item.product_variant.nil? || item.product_variant.available_for_purchase?)
    end
  end

  def subtotal_cents
    cart_items.includes(:product, :product_variant).sum(&:subtotal_cents)
  end

  def discount_cents
    return 0 unless coupon&.valid_for?(subtotal_cents)

    coupon.discount_cents_for(subtotal_cents)
  end
end
