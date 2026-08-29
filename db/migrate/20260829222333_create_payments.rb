class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :gateway, null: false
      t.string :external_id, null: false
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false

      t.timestamps
    end
  end
end
