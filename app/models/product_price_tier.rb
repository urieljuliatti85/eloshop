# Faixa de preço do insumo do distribuidor (ADR 007, Fase 26): "a partir de
# N unidades, X% de desconto" (decisão do Uriel, 2026-11-07). O desconto é em
# basis points (1_000 = 10%) e vale sobre o preço da variante, porque as
# variantes podem ter preços diferentes; a quantidade é a do produto inteiro,
# somando as variantes (5 cores do mesmo fio contam juntas).
#
# Modelada só pela quantidade mínima, sem limite superior: o índice único em
# `(product_id, min_quantity)` torna a sobreposição impossível, e a faixa que
# vale é a de maior mínimo já alcançado (`Product#price_tier_for`).
class ProductPriceTier < ApplicationRecord
  MAX_PER_PRODUCT = 5
  # Até 50% de desconto (decisão do Uriel, 2026-11-07): o preço com a faixa
  # nunca chega perto de zero. Também é constraint no banco.
  MAX_DISCOUNT_BPS = 5_000

  belongs_to :product, inverse_of: :price_tiers

  validates :min_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: Product::MAX_ORDER_QUANTITY }
  validates :discount_bps, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DISCOUNT_BPS }
  validates :min_quantity, uniqueness: { scope: :product_id }
  validate :only_for_a_distributor_product
  validate :above_the_minimum_order
  # Desconto crescente e no máximo cinco faixas, conferidos aqui também, e
  # não só no produto: uma faixa salva por outro caminho (console, admin,
  # duas abas) passava com desconto menor que a faixa abaixo dela, e quem
  # comprava mais pagava mais por unidade (achado do QA, 2026-11-07).
  validate :coherent_with_the_other_tiers

  scope :ordered, -> { order(:min_quantity) }

  # Desconto como o comprador lê: 1_050 → "10,5%".
  def discount_percent
    discount_bps / 100r if discount_bps
  end

  # O formulário do painel pede o desconto em %, como a pessoa pensa ("10" ou
  # "10,5"), e grava em basis points. Texto que não é número vira nil, e a
  # validação diz o que falta.
  def discount_percent=(value)
    text = value.to_s.strip.delete("%").tr(",", ".")
    self.discount_bps = text.match?(/\A\d+(\.\d{1,2})?\z/) ? (BigDecimal(text) * 100).to_i : nil
  end

  # Valor do campo no formulário: 1_050 → "10,5", 1_000 → "10".
  def discount_percent_input
    return "" unless discount_bps

    (discount_bps % 100).zero? ? (discount_bps / 100).to_s : format("%.2f", discount_bps / 100.0).sub(/0\z/, "").tr(".", ",")
  end

  # Preço de uma unidade com a faixa aplicada, em centavos inteiros. Arredonda
  # para baixo: a sobra de menos de um centavo fica com o comprador.
  def apply_to(unit_price_cents)
    unit_price_cents * (10_000 - discount_bps) / 10_000
  end

  private

  # Trava a linha do produto antes de ler as outras faixas: duas faixas
  # salvas ao mesmo tempo esperam uma pela outra, em vez de cada uma conferir
  # um conjunto que a outra está mudando. `save` valida dentro da transação,
  # então a trava dura até o commit. Trava pela consulta, sem recarregar o
  # produto em memória (no cadastro aninhado ele ainda tem alterações).
  def coherent_with_the_other_tiers
    return if product.nil? || product.new_record? || min_quantity.nil? || discount_bps.nil?

    Product.where(id: product_id).lock.pluck(:id)
    others = sibling_tiers_as_they_will_be

    if others.size >= MAX_PER_PRODUCT
      errors.add(:base, "o produto já tem #{MAX_PER_PRODUCT} faixas de preço")
    end
    if others.any? { |quantity, discount| quantity < min_quantity && discount >= discount_bps }
      errors.add(:discount_bps, "precisa ser maior que o da faixa de quantidade menor")
    end
    if others.any? { |quantity, discount| quantity > min_quantity && discount <= discount_bps }
      errors.add(:discount_bps, "precisa ser menor que o da faixa de quantidade maior")
    end
  end

  # As outras faixas do produto como ficarão depois deste save: as do banco,
  # trocadas pela versão em memória quando o produto as está editando junto
  # (cadastro aninhado), mais as novas, menos as marcadas para apagar.
  # Comparar só com o banco recusaria uma edição válida de várias faixas de
  # uma vez (de 10% e 20% para 25% e 30%, a primeira esbarraria nos 20%).
  def sibling_tiers_as_they_will_be
    tiers = ProductPriceTier.where(product_id: product_id).where.not(id: id)
      .pluck(:id, :min_quantity, :discount_bps).to_h { |tier_id, quantity, discount| [ tier_id, [ quantity, discount ] ] }
    product.price_tiers.target.each do |tier|
      next if tier.equal?(self)

      if tier.marked_for_destruction?
        tiers.delete(tier.id)
      else
        tiers[tier.id || tier.object_id] = [ tier.min_quantity.to_i, tier.discount_bps.to_i ]
      end
    end
    tiers.values
  end

  # Abaixo do mínimo a faixa valeria sempre. O resto da coerência entre as
  # faixas (desconto crescente, quantas cabem) é conferido no produto, que as
  # salva juntas (`Product#price_tiers_coherent`).
  def above_the_minimum_order
    return if product.nil? || min_quantity.to_i > product.min_order_quantity.to_i

    errors.add(:min_quantity, "precisa ser maior que a quantidade mínima de compra do produto")
  end

  def only_for_a_distributor_product
    return if product.nil? || product.supply?

    errors.add(:product, "só insumo de armarinho tem faixas de preço")
  end
end
