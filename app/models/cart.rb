class Cart < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :coupon, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :session_token, presence: true, uniqueness: true

  def subtotal_cents
    cart_items.includes(:product, :product_variant).sum(&:subtotal_cents)
  end

  def discount_cents
    return 0 unless coupon&.valid_for?(subtotal_cents)

    coupon.discount_cents_for(subtotal_cents)
  end

  # O pedido só é enviado quando a peça mais demorada fica pronta: é o maior
  # prazo de produção entre as peças sob encomenda que define a espera antes
  # do transporte. Nil quando nada no carrinho é sob encomenda.
  def production_time_max_days
    cart_items.includes(:product).filter_map { |item| item.product.production_time_max_days if item.product.availability_type_made_to_order? }.max
  end
end
