class CascadeShipmentsWithOrders < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :shipments, :orders
    add_foreign_key :shipments, :orders, on_delete: :cascade
  end
end
