class Product < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  STANDARD_STATUS_TRANSITIONS = {
    "draft" => %w[active],
    "active" => %w[draft sold_out discontinued],
    "sold_out" => %w[active discontinued],
    "discontinued" => []
  }.freeze

  # Uma peça única, uma vez vendida (sold_out), não pode "voltar" a ficar
  # disponível automaticamente — ver docs/inventory.md, "One of a Kind".
  ONE_OF_A_KIND_STATUS_TRANSITIONS = STANDARD_STATUS_TRANSITIONS.merge(
    "sold_out" => %w[discontinued]
  ).freeze

  MAIN_IMAGE_MAX_BYTES = 5.megabytes
  MAIN_IMAGE_ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  enum :status, {
    draft: "draft",
    active: "active",
    sold_out: "sold_out",
    discontinued: "discontinued"
  }, default: "draft"

  # "Pequena tiragem" não é um tipo à parte — é um produto standard com
  # stock_quantity > 1. Ver ROADMAP.md, Fase 8.
  enum :availability_type, {
    standard: "standard",
    one_of_a_kind: "one_of_a_kind",
    made_to_order: "made_to_order"
  }, default: "standard", prefix: true

  has_one_attached :main_image
  has_many :product_variants, dependent: :destroy

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :sku, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }

  validates :stock_quantity, numericality: { less_than_or_equal_to: 1 }, if: :availability_type_one_of_a_kind?
  validates :production_time_min_days, :production_time_max_days,
            presence: true, numericality: { greater_than: 0 }, if: :availability_type_made_to_order?
  validate :production_time_range_valid, if: :availability_type_made_to_order?

  validate :availability_type_immutable_while_has_variants, if: :availability_type_changed?

  validate :main_image_content_type_allowed
  validate :main_image_size_within_limit

  def publish!
    transition_to!("active")
  end

  def unpublish!
    transition_to!("draft")
  end

  def discontinue!
    transition_to!("discontinued")
  end

  # Fonte única de verdade sobre disponibilidade de compra — ver docs/inventory.md.
  # Produto sob encomenda não depende de estoque físico. Produto com
  # variantes (Fase 9) nunca é comprado "cru" — a decisão passa sempre pela
  # variante escolhida, então aqui só reflete se existe alguma opção comprável.
  def available_for_purchase?
    return false unless active?
    return product_variants.any?(&:available_for_purchase?) if has_variants?
    return true if availability_type_made_to_order?

    stock_quantity.positive?
  end

  def has_variants?
    product_variants.any?
  end

  # Snapshot textual do prazo de produção, gravado no pedido no momento da
  # compra (ver docs/checkout.md e docs/shipping.md — não confundir com
  # prazo de transporte).
  def production_time_range
    return nil unless availability_type_made_to_order?

    "#{production_time_min_days} a #{production_time_max_days} dias úteis"
  end

  def to_param
    slug
  end

  private

  def allowed_status_transitions
    availability_type_one_of_a_kind? ? ONE_OF_A_KIND_STATUS_TRANSITIONS : STANDARD_STATUS_TRANSITIONS
  end

  def transition_to!(new_status)
    unless allowed_status_transitions.fetch(status).include?(new_status)
      raise InvalidStatusTransition, "não é possível transicionar de #{status} para #{new_status}"
    end

    update!(status: new_status)
  end

  def assign_slug
    self.slug = name.parameterize
  end

  def production_time_range_valid
    return if production_time_min_days.blank? || production_time_max_days.blank?
    return if production_time_min_days <= production_time_max_days

    errors.add(:production_time_max_days, "deve ser maior ou igual ao prazo mínimo")
  end

  def main_image_content_type_allowed
    return unless main_image.attached?
    return if MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(main_image.content_type)

    errors.add(:main_image, "deve ser um arquivo PNG, JPEG ou WEBP")
  end

  def main_image_size_within_limit
    return unless main_image.attached?
    return if main_image.byte_size <= MAIN_IMAGE_MAX_BYTES

    errors.add(:main_image, "deve ter no máximo 5MB")
  end

  def availability_type_immutable_while_has_variants
    return if availability_type_standard?
    return unless persisted? && has_variants?

    errors.add(:availability_type, "não pode ser alterado enquanto o produto tiver variantes cadastradas")
  end
end
