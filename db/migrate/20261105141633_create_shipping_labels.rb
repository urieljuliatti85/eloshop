# Etiqueta comprada na SuperFrete pela carteira do ateliê (ADR 005, "Etapa 2
# e 3"). A SuperFrete não tem idempotência e o checkout debita a carteira: o
# estado é explícito e o id do pedido lá (`provider_order_id`) é gravado
# antes de pagar, para que uma falha no meio seja resolvida consultando o
# pedido, nunca criando outro.
class CreateShippingLabels < ActiveRecord::Migration[8.1]
  ACTIVE = %w[draft cart_created purchasing purchased].freeze

  def change
    create_table :shipping_labels do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.string :provider_order_id
      t.integer :service_code, null: false
      t.string :service_name, null: false
      t.integer :quoted_price_cents, null: false
      t.integer :price_cents
      t.integer :height_cm, null: false
      t.integer :width_cm, null: false
      t.integer :length_cm, null: false
      t.integer :weight_grams, null: false
      t.string :tracking_code
      t.boolean :sandbox, null: false
      t.string :superfrete_account_id, null: false
      t.string :failure_message
      t.datetime :purchased_at
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :shipping_labels, :provider_order_id, unique: true
    # Uma etiqueta viva por envio: cancelada ou que falhou não conta.
    add_index :shipping_labels, :shipment_id, unique: true, name: "index_shipping_labels_one_active_per_shipment",
      where: "status IN (#{ACTIVE.map { |status| "'#{status}'" }.join(', ')})"
    add_check_constraint :shipping_labels,
      "status IN ('draft', 'cart_created', 'purchasing', 'purchased', 'cancelled', 'failed')",
      name: "shipping_labels_status_check"
    add_check_constraint :shipping_labels,
      "height_cm > 0 AND width_cm > 0 AND length_cm > 0 AND weight_grams > 0",
      name: "shipping_labels_package_check"
    # Sem id na SuperFrete só antes de chegar lá: rascunho, ou rascunho que
    # falhou ou foi cancelado pelo ateliê.
    add_check_constraint :shipping_labels,
      "status IN ('draft', 'failed', 'cancelled') OR provider_order_id IS NOT NULL",
      name: "shipping_labels_provider_order_check"
  end
end
