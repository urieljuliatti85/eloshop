class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :subtotal_cents, null: false
      t.integer :shipping_cents, null: false
      t.integer :total_cents, null: false
      t.jsonb :shipping_address_snapshot, null: false
      t.string :idempotency_key, null: false

      t.timestamps
    end
    add_index :orders, :idempotency_key, unique: true
  end
end
