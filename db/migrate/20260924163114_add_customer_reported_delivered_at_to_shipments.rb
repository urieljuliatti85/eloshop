class AddCustomerReportedDeliveredAtToShipments < ActiveRecord::Migration[8.1]
  def change
    add_column :shipments, :customer_reported_delivered_at, :datetime
  end
end
