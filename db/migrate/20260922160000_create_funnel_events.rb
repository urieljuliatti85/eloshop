class CreateFunnelEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :funnel_events do |t|
      t.string :event_name, null: false
      t.date :occurred_on, null: false
      t.bigint :product_id
      t.bigint :seller_id
      t.integer :event_count, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :funnel_events, :products
    add_foreign_key :funnel_events, :sellers
    add_check_constraint :funnel_events, "event_count >= 0", name: "funnel_events_event_count_check"
    add_check_constraint :funnel_events, "amount_cents >= 0", name: "funnel_events_amount_cents_check"
    execute <<~SQL
      CREATE UNIQUE INDEX index_funnel_events_on_dimensions
      ON funnel_events (event_name, occurred_on, product_id, seller_id)
      NULLS NOT DISTINCT
    SQL
    add_index :funnel_events, %i[occurred_on event_name]
  end
end
