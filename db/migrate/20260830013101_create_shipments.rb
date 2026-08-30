class CreateShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :carrier, null: false
      t.string :service, null: false
      t.string :status, null: false, default: "pending"
      t.string :tracking_code
      t.integer :shipping_cents, null: false
      t.integer :estimated_days, null: false
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.timestamps
    end

    add_index :shipments, :tracking_code, unique: true
  end
end
