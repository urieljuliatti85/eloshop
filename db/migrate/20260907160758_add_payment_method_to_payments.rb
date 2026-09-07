class AddPaymentMethodToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payment_method, :string, null: false, default: "pix"
    add_column :payments, :installments, :integer, null: false, default: 1
    add_column :payments, :card_last_four, :string
    add_column :payments, :card_brand, :string

    add_check_constraint :payments, "payment_method IN ('pix', 'credit_card')", name: "payments_payment_method_check"
    add_check_constraint :payments, "installments >= 1", name: "payments_installments_check"
  end
end
