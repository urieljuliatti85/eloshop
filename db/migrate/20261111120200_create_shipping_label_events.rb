# Notificações do webhook da SuperFrete. Não há id de evento: a SuperFrete
# recomenda usar o par evento + id do pedido, daí o índice único. Só os
# campos extraídos são gravados, nunca o corpo cru.
class CreateShippingLabelEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :shipping_label_events do |t|
      t.references :shipping_label, null: false, foreign_key: true
      t.string :event, null: false
      t.string :provider_order_id, null: false
      t.string :status, null: false
      t.string :tracking_code
      t.datetime :processed_at
      t.timestamps
    end

    add_index :shipping_label_events, [ :provider_order_id, :event ], unique: true
  end
end
