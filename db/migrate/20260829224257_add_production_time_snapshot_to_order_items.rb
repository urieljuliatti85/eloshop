class AddProductionTimeSnapshotToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :production_time_snapshot, :string
  end
end
