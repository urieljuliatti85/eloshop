class CreateSellerReports < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_reports do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: true
      t.string :reason, null: false
      t.text :details
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :seller_reports, :status
    add_index :seller_reports, [ :customer_id, :seller_id ], unique: true
  end
end
