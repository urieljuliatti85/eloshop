class AddVariantSnapshotToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :order_items, :product_variant, foreign_key: true
    add_column :order_items, :variant_sku, :string
    add_column :order_items, :size_snapshot, :string
    add_column :order_items, :color_snapshot, :string
    add_column :order_items, :material_snapshot, :string
  end
end
