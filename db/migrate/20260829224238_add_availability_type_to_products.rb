class AddAvailabilityTypeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :availability_type, :string, null: false, default: "standard"
    add_column :products, :production_time_min_days, :integer
    add_column :products, :production_time_max_days, :integer
    add_index :products, :availability_type
  end
end
