class AddShippingDimensionsToProducts < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.integer :weight_grams
      t.integer :length_cm
      t.integer :width_cm
      t.integer :height_cm
    end
  end
end
