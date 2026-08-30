class CreateDiscoveryTaxonomies < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    create_table :materials do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    create_table :techniques do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :tags, :slug, unique: true
    add_index :materials, :slug, unique: true
    add_index :techniques, :slug, unique: true
    add_index :tags, "lower(name)", unique: true, name: "index_tags_on_lower_name"
    add_index :materials, "lower(name)", unique: true, name: "index_materials_on_lower_name"
    add_index :techniques, "lower(name)", unique: true, name: "index_techniques_on_lower_name"

    create_table :product_tags do |t|
      t.references :product, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_tags, [ :product_id, :tag_id ], unique: true

    create_table :product_materials do |t|
      t.references :product, null: false, foreign_key: true
      t.references :material, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_materials, [ :product_id, :material_id ], unique: true

    create_table :product_techniques do |t|
      t.references :product, null: false, foreign_key: true
      t.references :technique, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_techniques, [ :product_id, :technique_id ], unique: true
  end
end
