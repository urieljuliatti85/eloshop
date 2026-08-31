class AddPixFieldsToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :pix_qr_code, :text
    add_column :payments, :pix_qr_code_base64, :text
    add_column :payments, :expires_at, :datetime
  end
end
