# Solicitações pós-venda, Fase 1 (ADR 008): desistência, problema no produto
# e problema na entrega, por SellerOrder. Só cria tabelas novas — compatível
# com a versão anterior rodando durante o deploy.
class CreateReturnRequests < ActiveRecord::Migration[8.1]
  OPEN_STATUSES = %w[received in_progress awaiting_return].freeze

  def change
    create_table :return_requests do |t|
      t.references :seller_order, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "received"
      t.text :description
      t.date :respond_by, null: false
      t.datetime :resolved_at
      t.timestamps

      t.check_constraint "kind IN ('withdrawal', 'product_issue', 'delivery_issue')", name: "return_requests_kind_check"
      t.check_constraint "status IN ('received', 'in_progress', 'awaiting_return', 'resolved', 'closed')", name: "return_requests_status_check"
      t.check_constraint "description IS NULL OR char_length(description) <= 2000", name: "return_requests_description_length_check"
    end

    # Protocolo do decreto derivado do id (regra 6 do ADR 008): coluna gerada
    # pelo próprio banco, NOT NULL num passo só e sem MAX + 1. A sequence é a
    # do id, que o schema.rb já reproduz — uma sequence avulsa não seria
    # exportada para o banco de teste. `extract` sobre `timestamp` sem fuso e
    # os casts para texto são imutáveis, como coluna gerada exige.
    add_column :return_requests, :protocol, :virtual, type: :string, stored: true,
      as: "'ELO-' || (extract(year from created_at))::integer::text || '-' || lpad(id::text, 6, '0')"
    add_index :return_requests, :protocol, unique: true

    # Uma solicitação aberta por tipo e pedido: a segunda desistência acrescenta
    # itens à aberta (ADR 008, decisão B).
    add_index :return_requests, %i[seller_order_id kind], unique: true,
      where: "status IN (#{OPEN_STATUSES.map { |status| "'#{status}'" }.join(', ')})",
      name: "index_return_requests_one_open_per_kind"
    add_index :return_requests, %i[status respond_by]

    create_table :return_request_items do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :order_item, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps

      t.check_constraint "quantity > 0", name: "return_request_items_quantity_check"
      t.index %i[return_request_id order_item_id], unique: true
    end

    create_table :return_request_updates do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :author, polymorphic: true, null: false
      t.text :body
      t.string :from_status
      t.string :to_status
      t.timestamps

      t.check_constraint "author_type IN ('Customer', 'User')", name: "return_request_updates_author_type_check"
      t.check_constraint "body IS NULL OR char_length(body) <= 2000", name: "return_request_updates_body_length_check"
      t.check_constraint "char_length(btrim(coalesce(body, ''))) >= 1 OR to_status IS NOT NULL", name: "return_request_updates_content_check"
    end
  end
end
