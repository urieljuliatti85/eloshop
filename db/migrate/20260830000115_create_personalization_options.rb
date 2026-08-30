class CreatePersonalizationOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :personalization_options do |t|
      t.references :product, null: false, foreign_key: true
      t.string :label, null: false
      t.boolean :required, null: false, default: false
      t.integer :max_length, null: false, default: 100

      t.timestamps

      t.check_constraint "max_length > 0", name: "personalization_options_max_length_check"
    end

    add_index :personalization_options, [ :product_id, :label ], unique: true
  end
end
