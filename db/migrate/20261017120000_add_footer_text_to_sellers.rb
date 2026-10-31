class AddFooterTextToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :footer_text, :string, limit: 300
  end
end
