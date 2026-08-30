class AddPersonalizationsToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :personalizations, :jsonb, null: false, default: []
  end
end
