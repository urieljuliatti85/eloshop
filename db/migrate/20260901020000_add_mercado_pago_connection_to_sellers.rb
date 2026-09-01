class AddMercadoPagoConnectionToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :mercado_pago_user_id, :string
    add_column :sellers, :mercado_pago_access_token_ciphertext, :text
    add_column :sellers, :mercado_pago_refresh_token_ciphertext, :text
    add_column :sellers, :mercado_pago_token_expires_at, :datetime
    add_column :sellers, :mercado_pago_connected_at, :datetime
    add_column :sellers, :mercado_pago_live_mode, :boolean, null: false, default: false

    add_index :sellers, :mercado_pago_user_id, unique: true,
      where: "mercado_pago_user_id IS NOT NULL"
  end
end
