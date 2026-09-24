class AddFreeShippingToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :free_shipping, :boolean, default: false, null: false
  end
end
