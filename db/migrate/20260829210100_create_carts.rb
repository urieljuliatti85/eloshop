class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.string :session_token, null: false
      # Sem foreign key ainda: a tabela customers só existe a partir da Fase 4
      # (ver docs/domain.md e ROADMAP.md). A constraint é adicionada lá.
      t.bigint :customer_id

      t.timestamps
    end
    add_index :carts, :session_token, unique: true
    add_index :carts, :customer_id
  end
end
