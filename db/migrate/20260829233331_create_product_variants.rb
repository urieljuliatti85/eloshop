class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.integer :price_cents, null: false
      t.integer :stock_quantity, null: false, default: 0
      t.string :size
      t.string :color
      t.string :material
      t.boolean :active, null: false, default: true

      t.timestamps

      t.check_constraint "stock_quantity >= 0", name: "product_variants_stock_quantity_check"
      t.check_constraint "price_cents >= 0", name: "product_variants_price_cents_check"
    end

    add_index :product_variants, :sku, unique: true

    # Duas variantes do mesmo produto não podem representar a mesma
    # combinação comercial. COALESCE trata size/color/material ausentes
    # (NULL) como iguais entre si — sem isso, o Postgres considera cada NULL
    # distinto e a constraint não pegaria duplicatas com o mesmo eixo vazio.
    add_index :product_variants,
              "product_id, COALESCE(size, ''), COALESCE(color, ''), COALESCE(material, '')",
              unique: true,
              name: "index_product_variants_on_product_and_combination"
  end
end
