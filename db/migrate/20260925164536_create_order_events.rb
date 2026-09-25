class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events do |t|
      t.belongs_to :order, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :status
      t.string :error_class
      t.text :error_message
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :order_events, %i[order_id created_at]
  end
end
