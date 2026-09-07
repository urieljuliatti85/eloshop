class AddMelhorEnvioToSellers < ActiveRecord::Migration[8.1]
  def change
    # Mesmo padrão do Mercado Pago (mercado_pago_*): tokens cifrados, nunca em
    # texto puro. Sem coluna de user_id — a API do Melhor Envio não devolve
    # identificador de conta no token exchange (só access_token/refresh_token/
    # expires_in/token_type, confirmado na doc oficial), então não há como
    # replicar a validação "token renovado pertence à mesma conta" que o
    # Mercado Pago faz; o refresh token já está escopado ao vendedor no banco.
    add_column :sellers, :melhor_envio_access_token_ciphertext, :text
    add_column :sellers, :melhor_envio_refresh_token_ciphertext, :text
    add_column :sellers, :melhor_envio_token_expires_at, :datetime
    add_column :sellers, :melhor_envio_connected_at, :datetime
    add_column :sellers, :melhor_envio_sandbox, :boolean, null: false, default: false
  end
end
