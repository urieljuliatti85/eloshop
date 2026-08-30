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
  IMAGES_MAX_COUNT = 8

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
  # Fotos adicionais (galeria) — main_image continua sendo a capa,
  # explicitamente definida, ver docs/catalog.md "Imagens".
  has_many_attached :images
  has_many :product_variants, dependent: :destroy
  has_many :personalization_options, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :product_tags, dependent: :destroy
  has_many :tags, through: :product_tags
  has_many :product_materials, dependent: :destroy
  has_many :materials, through: :product_materials
  has_many :product_techniques, dependent: :destroy
  has_many :techniques, through: :product_techniques
  belongs_to :category, optional: true

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
  validate :images_content_type_allowed
  validate :images_size_within_limit
  validate :images_count_within_limit

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

  # Sem variante e sem personalização obrigatória — pode ser adicionado ao
  # carrinho diretamente (ex.: "mover para o carrinho" a partir da
  # wishlist), sem precisar passar pela PDP para escolher nada.
  def directly_purchasable?
    !has_variants? && personalization_options.none?(&:required?)
  end

  def approved_reviews
    reviews.visible.order(created_at: :desc)
  end

  def average_rating
    approved_reviews.average(:rating)&.round(1)
  end

  def reviews_count
    approved_reviews.count
  end

  # Menor preço entre as variantes ativas — usado no catálogo para produtos
  # com variante, já que o price_cents do próprio produto não representa
  # necessariamente nenhuma opção comprável (Fase 9, preço por variante).
  def starting_price_cents
    return price_cents unless has_variants?

    product_variants.select(&:active?).filter_map(&:price_cents).min || price_cents
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

  scope :matching_query, ->(query) {
    term = "%#{sanitize_sql_like(query.to_s.strip)}%"
    left_joins(:category, :tags, :materials, :techniques)
      .where(
        <<~SQL.squish,
          products.name ILIKE :term OR
          products.description ILIKE :term OR
          categories.name ILIKE :term OR
          tags.name ILIKE :term OR
          materials.name ILIKE :term OR
          techniques.name ILIKE :term
        SQL
        term: term
      )
      .distinct
  }

  RELATED_PRODUCTS_LIMIT = 4

  # Sem categorias/tags (Fase 11 ainda não implementada) para basear uma
  # recomendação real — decisão do negócio: outros produtos ativos, mais
  # recentes primeiro. Reavaliar quando a Fase 11 existir.
  def related_products(limit: RELATED_PRODUCTS_LIMIT)
    Product.active.where.not(id: id).order(created_at: :desc).limit(limit)
  end

  # Capa (main_image) primeiro, depois o resto da galeria — main_image
  # continua sendo a foto explicitamente definida como principal, nunca
  # depende da ordem acidental dos anexos (ver docs/catalog.md, "Imagens").
  def gallery_images
    photos = []
    photos << main_image if main_image.attached?
    photos.concat(images.to_a)
    photos
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

  def images_content_type_allowed
    return unless images.attached?
    return if images.all? { |image| MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(image.content_type) }

    errors.add(:images, "deve conter apenas arquivos PNG, JPEG ou WEBP")
  end

  def images_size_within_limit
    return unless images.attached?
    return if images.all? { |image| image.byte_size <= MAIN_IMAGE_MAX_BYTES }

    errors.add(:images, "cada imagem deve ter no máximo 5MB")
  end

  def images_count_within_limit
    return if images.size <= IMAGES_MAX_COUNT

    errors.add(:images, "não pode ter mais de #{IMAGES_MAX_COUNT} imagens")
  end

  def availability_type_immutable_while_has_variants
    return if availability_type_standard?
    return unless persisted? && has_variants?

    errors.add(:availability_type, "não pode ser alterado enquanto o produto tiver variantes cadastradas")
  end
end
