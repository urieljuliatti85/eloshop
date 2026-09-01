require "digest"

class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  # Duas personalizações diferentes do mesmo produto (ex.: duas canecas
  # gravadas com nomes diferentes) precisam ser linhas separadas no
  # carrinho — por isso personalization_digest entra no escopo de
  # unicidade. Ele nunca é nulo (mesmo sem personalização vira o digest de
  # "[]"), então a comparação funciona sem o truque de COALESCE usado para
  # product_variant_id.
  validates :product_id, uniqueness: { scope: %i[cart_id product_variant_id personalization_digest] }
  validates :quantity, numericality: { greater_than: 0 }

  before_validation :normalize_personalizations
  before_validation :compute_personalization_digest

  validate :variant_required_or_forbidden
  validate :variant_belongs_to_product
  validate :product_available_for_requested_quantity
  validate :personalizations_valid_for_product
  validate :same_seller_as_cart

  def unit_price_cents
    product_variant&.price_cents || product.price_cents
  end

  def subtotal_cents
    quantity * unit_price_cents
  end

  # Junta o valor salvo com o label atual da opção (o carrinho não é uma
  # compra confirmada, então ainda é seguro depender da configuração
  # corrente do produto — só o Order precisa de um snapshot totalmente
  # independente). Ignora silenciosamente uma opção removida depois.
  def personalization_entries
    options_by_id = product.personalization_options.index_by(&:id)

    personalizations.filter_map do |entry|
      option = options_by_id[entry["personalization_option_id"]]
      next unless option

      { label: option.label, value: entry["value"] }
    end
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

  # Nunca confia na forma como o cliente enviou o payload — reduz cada
  # entrada só ao par (option id, valor), descarta valores em branco (o que
  # equivale a "não preenchido" para efeito de campo obrigatório) e ignora
  # qualquer outra chave estranha.
  def normalize_personalizations
    self.personalizations = Array(personalizations).filter_map do |entry|
      option_id = entry["personalization_option_id"] || entry[:personalization_option_id]
      value = (entry["value"] || entry[:value]).to_s.strip

      next if option_id.blank? || value.blank?

      { "personalization_option_id" => option_id.to_i, "value" => value }
    end
  end

  def compute_personalization_digest
    sorted = personalizations.sort_by { |entry| entry["personalization_option_id"] }
    self.personalization_digest = Digest::SHA256.hexdigest(sorted.to_json)
  end

  def personalizations_valid_for_product
    return if product.blank?

    options_by_id = product.personalization_options.index_by(&:id)
    submitted_ids = personalizations.map { |entry| entry["personalization_option_id"] }

    if submitted_ids.uniq.length != submitted_ids.length
      errors.add(:personalizations, "não pode repetir o mesmo campo")
      return
    end

    if submitted_ids.any? { |id| !options_by_id.key?(id) }
      errors.add(:personalizations, "contém um campo que não pertence a este produto")
      return
    end

    personalizations.each do |entry|
      option = options_by_id.fetch(entry["personalization_option_id"])

      if entry["value"].length > option.max_length
        errors.add(:personalizations, "#{option.label} deve ter no máximo #{option.max_length} caracteres")
      end
    end

    options_by_id.each_value do |option|
      next unless option.required?
      next if submitted_ids.include?(option.id)

      errors.add(:personalizations, "#{option.label} é obrigatório")
    end
  end

  def same_seller_as_cart
    return if cart.blank? || product.blank?

    other_seller_ids = cart.cart_items.where.not(id: id).joins(:product).distinct.pluck("products.seller_id")
    return if other_seller_ids.empty? || other_seller_ids == [ product.seller_id ]

    errors.add(:product, "deve ser do mesmo artesão dos outros itens do carrinho")
  end
end
