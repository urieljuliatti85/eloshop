class CreateCategorySuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :category_suggestions do |t|
      t.string :name, null: false, limit: 60
      # `name.squish.parameterize`, a mesma regra do slug de Category: ignora
      # caixa, acento e espaço. É por ela que sugestões iguais viram uma só.
      t.string :normalized_key, null: false, limit: 80
      t.string :status, null: false, default: "pending"
      # `on_delete: :nullify` nas duas: apagar a categoria criada (sem produtos)
      # ou remover o admin que decidiu não pode esbarrar no histórico da
      # sugestão. Aceita com `category_id` nulo = categoria apagada depois.
      t.references :category, foreign_key: { on_delete: :nullify }
      t.references :decided_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :decided_at
      t.timestamps
    end

    # Só uma sugestão pendente por nome. Parcial de propósito: um nome
    # recusado pode voltar como sugestão nova (decisão de 2026-11-04).
    add_index :category_suggestions, :normalized_key, unique: true, where: "status = 'pending'",
      name: "index_category_suggestions_on_pending_key"
    add_index :category_suggestions, %i[status created_at]
    add_check_constraint :category_suggestions, "status IN ('pending', 'accepted', 'rejected')",
      name: "category_suggestions_status_check"

    # Quem sugeriu: um ateliê uma vez por sugestão. `notified_at` torna o
    # e-mail da decisão idempotente por ateliê.
    create_table :category_suggestion_requests do |t|
      t.references :category_suggestion, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: true
      t.datetime :notified_at
      t.timestamps
    end

    add_index :category_suggestion_requests, %i[category_suggestion_id seller_id], unique: true,
      name: "index_category_suggestion_requests_on_suggestion_and_seller"
  end
end
