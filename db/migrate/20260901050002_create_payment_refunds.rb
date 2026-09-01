class CreatePaymentRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_refunds do |t|
      t.references :payment, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "processing"
      t.integer :amount_cents, null: false
      t.integer :application_fee_amount_cents, null: false

      t.timestamps
    end

    add_index :payment_refunds, :idempotency_key, unique: true
    add_check_constraint :payment_refunds, "status IN ('processing', 'approved', 'failed')", name: "payment_refunds_status_check"
    add_check_constraint :payment_refunds, "amount_cents > 0", name: "payment_refunds_amount_check"
    add_check_constraint :payment_refunds, "application_fee_amount_cents >= 0 AND application_fee_amount_cents <= amount_cents", name: "payment_refunds_fee_check"
  end
end
