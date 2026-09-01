class CreateSellerOrders < ActiveRecord::Migration[8.1]
  PLATFORM_FEE_RATE_BPS = 1_500

  def up
    create_table :seller_orders do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.references :seller, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :currency, null: false, default: "BRL"
      t.integer :subtotal_cents, null: false
      t.integer :discount_cents, null: false, default: 0
      t.integer :shipping_cents, null: false
      t.integer :total_cents, null: false
      t.integer :platform_fee_rate_bps, null: false, default: PLATFORM_FEE_RATE_BPS
      t.integer :platform_fee_cents, null: false
      t.integer :seller_amount_cents, null: false
      t.integer :refunded_amount_cents, null: false, default: 0
      t.integer :platform_fee_refunded_cents, null: false, default: 0

      t.timestamps
    end

    add_index :seller_orders, %i[order_id seller_id], unique: true
    add_check_constraint :seller_orders, "status IN ('pending', 'confirmed', 'cancelled', 'partially_refunded', 'refunded')", name: "seller_orders_status_check"
    add_check_constraint :seller_orders, "subtotal_cents >= 0", name: "seller_orders_subtotal_check"
    add_check_constraint :seller_orders, "discount_cents >= 0 AND discount_cents <= subtotal_cents", name: "seller_orders_discount_check"
    add_check_constraint :seller_orders, "shipping_cents >= 0", name: "seller_orders_shipping_check"
    add_check_constraint :seller_orders, "total_cents = subtotal_cents - discount_cents + shipping_cents", name: "seller_orders_total_check"
    add_check_constraint :seller_orders, "platform_fee_rate_bps BETWEEN 0 AND 10000", name: "seller_orders_fee_rate_check"
    add_check_constraint :seller_orders, "platform_fee_cents >= 0 AND platform_fee_cents <= subtotal_cents - discount_cents", name: "seller_orders_fee_check"
    add_check_constraint :seller_orders, "seller_amount_cents = total_cents - platform_fee_cents", name: "seller_orders_seller_amount_check"
    add_check_constraint :seller_orders, "refunded_amount_cents >= 0 AND refunded_amount_cents <= total_cents", name: "seller_orders_refunded_amount_check"
    add_check_constraint :seller_orders, "platform_fee_refunded_cents >= 0 AND platform_fee_refunded_cents <= platform_fee_cents", name: "seller_orders_fee_refunded_check"

    add_reference :order_items, :seller_order, foreign_key: { on_delete: :cascade }
    add_reference :shipments, :seller_order, foreign_key: { on_delete: :cascade }

    backfill_seller_orders!

    change_column_null :order_items, :seller_order_id, false
    change_column_null :shipments, :seller_order_id, false
    remove_reference :shipments, :order, foreign_key: true
  end

  def down
    add_reference :shipments, :order, foreign_key: { on_delete: :cascade }
    execute <<~SQL
      UPDATE shipments
      SET order_id = seller_orders.order_id
      FROM seller_orders
      WHERE shipments.seller_order_id = seller_orders.id
    SQL
    change_column_null :shipments, :order_id, false

    remove_reference :shipments, :seller_order, foreign_key: true
    remove_reference :order_items, :seller_order, foreign_key: true
    drop_table :seller_orders
  end

  private

  def backfill_seller_orders!
    mixed_order_id = select_value(<<~SQL)
      SELECT order_items.order_id
      FROM order_items
      INNER JOIN products ON products.id = order_items.product_id
      GROUP BY order_items.order_id
      HAVING COUNT(DISTINCT products.seller_id) > 1
      LIMIT 1
    SQL
    raise "pedido legado #{mixed_order_id} contém itens de vendedores diferentes" if mixed_order_id

    legacy_seller_id = select_value("SELECT id FROM sellers WHERE slug = 'eloshop' LIMIT 1")
    if select_value("SELECT 1 FROM orders LIMIT 1") && legacy_seller_id.blank?
      raise "vendedor legado EloShop não encontrado para o backfill de pedidos"
    end

    execute <<~SQL
      INSERT INTO seller_orders (
        order_id, seller_id, status, currency, subtotal_cents, discount_cents,
        shipping_cents, total_cents, platform_fee_rate_bps,
        platform_fee_cents, seller_amount_cents, refunded_amount_cents,
        platform_fee_refunded_cents, created_at, updated_at
      )
      SELECT
        orders.id,
        COALESCE(MIN(products.seller_id), #{connection.quote(legacy_seller_id)}),
        orders.status,
        'BRL',
        orders.subtotal_cents,
        orders.discount_cents,
        orders.shipping_cents,
        orders.total_cents,
        #{PLATFORM_FEE_RATE_BPS},
        ROUND((GREATEST(orders.subtotal_cents - orders.discount_cents, 0)::numeric * #{PLATFORM_FEE_RATE_BPS}) / 10000)::integer,
        orders.total_cents - ROUND((GREATEST(orders.subtotal_cents - orders.discount_cents, 0)::numeric * #{PLATFORM_FEE_RATE_BPS}) / 10000)::integer,
        0,
        0,
        orders.created_at,
        orders.updated_at
      FROM orders
      LEFT JOIN order_items ON order_items.order_id = orders.id
      LEFT JOIN products ON products.id = order_items.product_id
      GROUP BY orders.id
    SQL

    execute <<~SQL
      UPDATE order_items
      SET seller_order_id = seller_orders.id
      FROM seller_orders
      WHERE order_items.order_id = seller_orders.order_id
    SQL

    execute <<~SQL
      UPDATE shipments
      SET seller_order_id = seller_orders.id
      FROM seller_orders
      WHERE shipments.order_id = seller_orders.order_id
    SQL
  end
end
