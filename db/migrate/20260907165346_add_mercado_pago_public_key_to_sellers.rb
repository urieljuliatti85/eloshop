class AddMercadoPagoPublicKeyToSellers < ActiveRecord::Migration[8.1]
  def change
    # Sem cifrar: a Public Key é pública por design — é o que o Card Payment
    # Brick usa no navegador para tokenizar, diferente do Access Token
    # (mercado_pago_access_token_ciphertext), que é segredo e fica cifrado.
    add_column :sellers, :mercado_pago_public_key, :string
  end
end
