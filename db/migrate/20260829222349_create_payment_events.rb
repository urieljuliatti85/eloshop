class CreatePaymentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_events do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :gateway_event_id, null: false
      t.jsonb :payload
      t.datetime :processed_at

      t.timestamps
    end
    add_index :payment_events, :gateway_event_id, unique: true
  end
end
