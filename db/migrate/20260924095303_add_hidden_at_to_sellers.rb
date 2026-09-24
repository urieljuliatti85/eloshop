class AddHiddenAtToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :hidden_at, :datetime
  end
end
