# Quem pode chamar a API v1 e ler a documentação. O token nunca é gravado:
# só o SHA-256 dele, buscado por índice único. Revogar marca a data em vez
# de apagar, para o histórico de quem teve acesso continuar consultável.
class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :api_clients, :token_digest, unique: true
    add_index :api_clients, :name, unique: true
  end
end
