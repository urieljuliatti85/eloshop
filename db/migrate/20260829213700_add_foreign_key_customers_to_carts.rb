class AddForeignKeyCustomersToCarts < ActiveRecord::Migration[8.1]
  def change
    # A coluna carts.customer_id foi criada sem FK na Fase 3, já que a tabela
    # customers ainda não existia (ver ROADMAP.md, Fase 3).
    add_foreign_key :carts, :customers
  end
end
