require "test_helper"

# Insumo do distribuidor (ADR 007, Fase 26, decisões de 2026-11-07): unidade
# de venda com descrição, quantidade mínima e faixas de desconto em %.
class ProductPriceTierTest < ActiveSupport::TestCase
  setup do
    @distributor = Seller.create!(name: "Fios Faixas", owner_full_name: "Dona dos Fios", cpf: "52998224725",
      kind: "distributor", status: :approved, approved_at: 1.day.ago)
    @supply = Product.create!(seller: @distributor, name: "Fio de algodão cru", price_cents: 2_500, stock_quantity: 100,
      status: :active, sale_unit: :pack, sale_unit_detail: "  pacote   com 100 g ")
  end

  test "a supply keeps its sale unit, a squished detail and a minimum of 1 by default" do
    assert @supply.supply?
    assert @supply.sold_by_pack?
    assert_equal "pacote com 100 g", @supply.sale_unit_detail
    assert_equal 1, @supply.min_order_quantity
    assert_equal "pacote", @supply.sale_unit_name
    assert_equal "pacotes", @supply.sale_unit_name(10)
  end

  test "an atelier piece cannot have unit, detail, minimum or tiers" do
    piece = products(:one)

    piece.assign_attributes(sale_unit: :pack, sale_unit_detail: "pacote", min_order_quantity: 3)
    assert_not piece.valid?
    assert_equal %i[sale_unit sale_unit_detail min_order_quantity].sort, piece.errors.attribute_names.sort

    tier = piece.price_tiers.build(min_quantity: 10, discount_bps: 1_000)
    assert_not tier.valid?
    assert_includes tier.errors[:product], "só insumo de distribuidor tem faixas de preço"
  end

  test "the database refuses an unknown unit, a minimum of zero and invalid tiers" do
    assert_raises(ActiveRecord::StatementInvalid) { @supply.update_columns(sale_unit: "barrel") }
    assert_raises(ActiveRecord::StatementInvalid) { @supply.update_columns(min_order_quantity: 0) }
    assert_raises(ActiveRecord::StatementInvalid) { ProductPriceTier.insert_all!([ { product_id: @supply.id, min_quantity: 1, discount_bps: 500 } ]) }
    assert_raises(ActiveRecord::StatementInvalid) { ProductPriceTier.insert_all!([ { product_id: @supply.id, min_quantity: 5, discount_bps: 10_000 } ]) }
  end

  test "two tiers can never share the same minimum, not even in the database" do
    @supply.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)

    assert_not @supply.price_tiers.build(min_quantity: 10, discount_bps: 2_000).valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ProductPriceTier.insert_all!([ { product_id: @supply.id, min_quantity: 10, discount_bps: 2_000 } ])
    end
  end

  test "tiers start above the minimum order and give a bigger discount at each step" do
    @supply.update!(min_order_quantity: 10)

    assert_not @supply.price_tiers.build(min_quantity: 10, discount_bps: 500).valid?, "faixa no mínimo valeria sempre"
    @supply.price_tiers.reset

    @supply.price_tiers.build(min_quantity: 20, discount_bps: 1_000)
    @supply.price_tiers.build(min_quantity: 50, discount_bps: 800)
    assert_not @supply.valid?
    assert_includes @supply.errors[:price_tiers], "precisam ter desconto maior a cada faixa"
  end

  test "raising the minimum above an existing tier is refused" do
    @supply.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)

    @supply.reload.price_tiers.load
    @supply.min_order_quantity = 10
    assert_not @supply.valid?
    assert_includes @supply.errors[:price_tiers], "precisam começar acima da quantidade mínima de compra"
  end

  test "a product holds at most five tiers" do
    6.times { |index| @supply.price_tiers.build(min_quantity: 10 * (index + 1), discount_bps: 100 * (index + 1)) }

    assert_not @supply.valid?
    assert_includes @supply.errors[:price_tiers], "podem ser no máximo 5"
  end

  # O exemplo do Uriel: R$ 25,00, 10% a partir de 10, 18% a partir de 50.
  test "the tier of the reached quantity applies, rounding the unit price down" do
    @supply.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)
    @supply.price_tiers.create!(min_quantity: 50, discount_bps: 1_800)
    @supply.reload

    assert_nil @supply.price_tier_for(9)
    assert_equal 2_500, @supply.unit_price_for(9)
    assert_equal 2_250, @supply.unit_price_for(10)
    assert_equal 2_250, @supply.unit_price_for(49)
    assert_equal 2_050, @supply.unit_price_for(50)
    assert_equal 2_050, @supply.unit_price_for(500)

    # Sobre o preço da variante, não o do produto: 3_333 com 18% = 2_733,06 → 2_733.
    assert_equal 2_733, @supply.unit_price_for(50, unit_price_cents: 3_333)
    assert_equal 18r, @supply.price_tier_for(50).discount_percent
  end

  test "the minimum and the tier count the whole product, summing the variants" do
    @supply.update!(stock_quantity: 0)
    @supply.product_variants.create!(sku: "FIO-AZUL", price_cents: 2_500, stock_quantity: 4, color: "Azul")
    @supply.product_variants.create!(sku: "FIO-VERDE", price_cents: 2_700, stock_quantity: 5, color: "Verde")
    @supply.product_variants.create!(sku: "FIO-ROSA", price_cents: 2_700, stock_quantity: 50, color: "Rosa", active: false)
    @supply.reload

    assert_equal 9, @supply.stock_for_minimum, "a variante inativa não conta"
    @supply.update!(min_order_quantity: 9)
    assert_not @supply.below_minimum_stock?
    @supply.update!(min_order_quantity: 10)
    assert @supply.below_minimum_stock?
  end

  # Mínimo maior que o estoque torna o insumo indisponível pela fonte única.
  test "a minimum above the stock blocks the purchase through purchase_blocker" do
    @supply.update!(stock_quantity: 5, min_order_quantity: 6)

    assert @supply.below_minimum_stock?
    assert_not @supply.available_for_purchase?
  end

  test "an atelier piece keeps its availability, with the neutral minimum" do
    piece = products(:one)

    assert_equal 1, piece.min_order_quantity
    assert_not piece.below_minimum_stock?
    assert_equal piece.price_cents, piece.unit_price_for(100)
  end

  test "destroying the product removes its tiers" do
    @supply.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)

    assert_difference -> { ProductPriceTier.count }, -1 do
      @supply.product_variants.destroy_all
      @supply.destroy!
    end
  end

  # Achado do QA (2026-11-07): salva direto, sem passar pelo produto, a faixa
  # aceitava desconto menor que o da faixa de baixo e passava de cinco.
  test "a tier saved on its own still needs a bigger discount than the lower tier and a smaller one than the higher" do
    ProductPriceTier.create!(product: @supply, min_quantity: 10, discount_bps: 2_000)

    lower_discount = ProductPriceTier.new(product: @supply, min_quantity: 50, discount_bps: 500)
    assert_not lower_discount.save
    assert_includes lower_discount.errors[:discount_bps], "precisa ser maior que o da faixa de quantidade menor"

    higher_discount = ProductPriceTier.new(product: @supply, min_quantity: 5, discount_bps: 2_500)
    assert_not higher_discount.save
    assert_includes higher_discount.errors[:discount_bps], "precisa ser menor que o da faixa de quantidade maior"

    assert_equal 2_000, Product.find(@supply.id).unit_price_for(50), "quem compra mais nunca paga mais por unidade"
  end

  test "a tier saved on its own cannot be the sixth" do
    5.times { |index| ProductPriceTier.create!(product: @supply, min_quantity: 10 * (index + 1), discount_bps: 100 * (index + 1)) }

    sixth = ProductPriceTier.new(product: @supply, min_quantity: 100, discount_bps: 1_000)
    assert_not sixth.save
    assert_includes sixth.errors[:base], "o produto já tem 5 faixas de preço"
  end

  # A checagem da faixa compara com o estado final, não com o banco: editar
  # várias faixas juntas pelo produto (o formulário do painel, PR B) não pode
  # esbarrar nos valores antigos das outras.
  test "editing several tiers together through the product compares with the final values" do
    @supply.price_tiers.create!(min_quantity: 10, discount_bps: 1_000)
    @supply.price_tiers.create!(min_quantity: 50, discount_bps: 2_000)
    supply = Product.find(@supply.id)

    first, second = supply.price_tiers.to_a
    assert supply.update(price_tiers_attributes: [ { id: first.id, discount_bps: 2_500 }, { id: second.id, discount_bps: 3_000 } ]),
      supply.errors.full_messages.to_sentence
    assert_equal [ 2_500, 3_000 ], supply.reload.price_tiers.map(&:discount_bps)
  end

  test "the discount goes up to 50%, in the model and in the database" do
    assert @supply.price_tiers.build(min_quantity: 10, discount_bps: 5_000).valid?
    assert_not @supply.price_tiers.build(min_quantity: 20, discount_bps: 5_001).valid?
    assert_raises(ActiveRecord::StatementInvalid) do
      ProductPriceTier.insert_all!([ { product_id: @supply.id, min_quantity: 20, discount_bps: 5_001 } ])
    end
  end

  # Achado do QA (2026-11-07): 3 bilhões passava da coluna inteira e virava
  # ActiveModel::RangeError (500) em vez de mensagem.
  test "quantities above 100,000 are a validation error, not an exception" do
    assert_not @supply.update(min_order_quantity: 3_000_000_000)
    assert @supply.errors.of_kind?(:min_order_quantity, :less_than_or_equal_to)

    tier = ProductPriceTier.new(product: Product.find(@supply.id), min_quantity: 3_000_000_000, discount_bps: 100)
    assert_not tier.save
    assert tier.errors.of_kind?(:min_quantity, :less_than_or_equal_to)
  end
end
