class CreateMercadoPagoTestAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :mercado_pago_test_accounts do |t|
      t.string :account_type, null: false
      t.string :label, null: false
      t.string :email
      t.string :mercado_pago_user_id
      t.string :username
      t.text :password_ciphertext
      t.string :verification_code

      t.timestamps
    end

    add_index :mercado_pago_test_accounts, :account_type
  end
end
