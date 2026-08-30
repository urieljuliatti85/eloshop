class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :product_name, :sku, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  def subtotal_cents
    unit_price_cents * quantity
  end

  # Snapshot da variante no momento da compra — nunca reconstruído a partir
  # da ProductVariant atual, que pode mudar ou ser removida depois.
  def variant_label
    [ size_snapshot, color_snapshot, material_snapshot ].compact_blank.join(" / ")
  end

  # Snapshot da personalização no momento da compra — já vem com label e
  # valor prontos, sem depender de PersonalizationOption continuar existindo.
  def personalization_entries
    personalizations.map { |entry| { label: entry["label"], value: entry["value"] } }
  end
end
