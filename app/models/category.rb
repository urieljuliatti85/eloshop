class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true, uniqueness: { scope: :parent_id }
  validates :slug, presence: true, uniqueness: true

  validate :parent_is_not_self_or_descendant

  def to_param
    slug
  end

  # Nome completo com a hierarquia, ex.: "Casa > Decoração" — usado no
  # seletor do admin e no breadcrumb da loja.
  def breadcrumb_name
    ancestors.reverse.map(&:name).push(name).join(" > ")
  end

  def ancestors
    parent ? [ parent, *parent.ancestors ] : []
  end

  # Inclui a própria categoria — usado para filtrar produtos: uma categoria
  # "pai" (ex.: Casa) deve mostrar também os produtos das subcategorias
  # (ex.: Casa > Decoração), senão uma categoria só com subcategorias
  # apareceria vazia.
  def self_and_descendant_ids
    [ id, *children.flat_map(&:self_and_descendant_ids) ]
  end

  private

  def assign_slug
    self.slug = name.parameterize
  end

  def parent_is_not_self_or_descendant
    return if parent.blank?

    if parent == self || (persisted? && self_and_descendant_ids.include?(parent.id))
      errors.add(:parent, "não pode ser a própria categoria nem uma subcategoria dela")
    end
  end
end
