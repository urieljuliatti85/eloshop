# Insumo do distribuidor (ADR 007, Fase 26): unidade de venda, o que vem nela,
# quantidade mínima e faixas de desconto por quantidade. Tudo opcional ou com
# padrão neutro: produto de ateliê não muda (unidade nula, mínimo 1, sem
# faixas), e a versão anterior da aplicação, que não conhece as colunas,
# continua funcionando durante o deploy.
class AddSupplyFieldsToProducts < ActiveRecord::Migration[8.1]
  SALE_UNITS = %w[unit pack meter kilogram roll box].freeze

  def change
    add_column :products, :sale_unit, :string
    add_column :products, :sale_unit_detail, :string
    add_column :products, :min_order_quantity, :integer, null: false, default: 1

    add_check_constraint :products, "sale_unit IS NULL OR sale_unit IN (#{SALE_UNITS.map { |unit| "'#{unit}'" }.join(", ")})",
      name: "products_sale_unit_check"
    add_check_constraint :products, "sale_unit_detail IS NULL OR char_length(sale_unit_detail) <= 60",
      name: "products_sale_unit_detail_length_check"
    add_check_constraint :products, "min_order_quantity BETWEEN 1 AND 100000", name: "products_min_order_quantity_check"

    # Faixa modelada só pela quantidade mínima, sem limite superior: o índice
    # único torna a sobreposição impossível por construção. O desconto é em
    # basis points (1 = 0,01%), inteiro como o resto do dinheiro, e vai até
    # 50% (decisão do Uriel, 2026-11-07), para o preço nunca chegar perto de
    # zero. O teto de 100.000 unidades está muito acima de qualquer pedido e
    # longe do limite da coluna inteira.
    create_table :product_price_tiers do |t|
      t.references :product, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :min_quantity, null: false
      t.integer :discount_bps, null: false
      t.timestamps
    end
    add_index :product_price_tiers, %i[product_id min_quantity], unique: true
    add_check_constraint :product_price_tiers, "min_quantity BETWEEN 2 AND 100000", name: "product_price_tiers_min_quantity_check"
    add_check_constraint :product_price_tiers, "discount_bps BETWEEN 1 AND 5000", name: "product_price_tiers_discount_bps_check"
  end
end
