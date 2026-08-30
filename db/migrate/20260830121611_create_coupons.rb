class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.string :discount_type, null: false
      t.integer :percentage
      t.integer :amount_cents
      t.integer :minimum_subtotal_cents
      t.integer :max_uses
      t.integer :uses_count, null: false, default: 0
      t.datetime :starts_at
      t.datetime :expires_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :coupons, :code, unique: true
  end
end
