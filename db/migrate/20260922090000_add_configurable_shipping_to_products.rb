class AddConfigurableShippingToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :fixed_shipping_cents, :integer
    add_column :products, :fixed_shipping_estimated_days, :integer
    add_column :products, :local_pickup_enabled, :boolean, default: false, null: false

    add_check_constraint :products,
      "fixed_shipping_cents IS NULL OR fixed_shipping_cents > 0",
      name: "products_fixed_shipping_cents_check"
    add_check_constraint :products,
      "fixed_shipping_estimated_days IS NULL OR fixed_shipping_estimated_days > 0",
      name: "products_fixed_shipping_days_check"
    add_check_constraint :products,
      "(fixed_shipping_cents IS NULL) = (fixed_shipping_estimated_days IS NULL)",
      name: "products_fixed_shipping_complete_check"
  end
end
