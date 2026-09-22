class CreateOrderMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :order_messages do |t|
      t.references :seller_order, null: false, foreign_key: { on_delete: :cascade }
      t.references :sender, polymorphic: true, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :order_messages, %i[seller_order_id created_at id], name: "index_order_messages_on_conversation_order"
    add_check_constraint :order_messages,
      "sender_type IN ('Customer', 'User')",
      name: "order_messages_sender_type_check"
    add_check_constraint :order_messages,
      "char_length(btrim(body)) BETWEEN 1 AND 2000",
      name: "order_messages_body_length_check"
  end
end
