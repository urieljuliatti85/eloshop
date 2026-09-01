class AddSplitAccountingToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :application_fee_cents, :integer, null: false, default: 0
    add_column :payments, :processor_fee_cents, :integer
    add_column :payments, :refunded_amount_cents, :integer, null: false, default: 0
    add_column :payments, :application_fee_refunded_cents, :integer, null: false, default: 0

    add_check_constraint :payments, "application_fee_cents >= 0 AND application_fee_cents <= amount_cents", name: "payments_application_fee_check"
    add_check_constraint :payments, "processor_fee_cents IS NULL OR processor_fee_cents >= 0", name: "payments_processor_fee_check"
    add_check_constraint :payments, "refunded_amount_cents >= 0 AND refunded_amount_cents <= amount_cents", name: "payments_refunded_amount_check"
    add_check_constraint :payments, "application_fee_refunded_cents >= 0 AND application_fee_refunded_cents <= application_fee_cents", name: "payments_application_fee_refunded_check"
  end
end
