class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "BRL"
      t.string :sku, null: false
      t.integer :stock_quantity, null: false, default: 0
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :products, :slug, unique: true
    add_index :products, :sku, unique: true
    add_index :products, :status
  end
end
