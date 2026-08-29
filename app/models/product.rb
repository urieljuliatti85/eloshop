class Product < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  ALLOWED_STATUS_TRANSITIONS = {
    "draft" => %w[active],
    "active" => %w[draft sold_out discontinued],
    "sold_out" => %w[active discontinued],
    "discontinued" => []
  }.freeze

  MAIN_IMAGE_MAX_BYTES = 5.megabytes
  MAIN_IMAGE_ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  enum :status, {
    draft: "draft",
    active: "active",
    sold_out: "sold_out",
    discontinued: "discontinued"
  }, default: "draft"

  has_one_attached :main_image

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :sku, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }

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
  def available_for_purchase?
    active? && stock_quantity.positive?
  end

  private

  def transition_to!(new_status)
    unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(new_status)
      raise InvalidStatusTransition, "não é possível transicionar de #{status} para #{new_status}"
    end

    update!(status: new_status)
  end

  def assign_slug
    self.slug = name.parameterize
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
end
