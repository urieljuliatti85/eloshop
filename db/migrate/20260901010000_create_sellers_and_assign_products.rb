class CreateSellersAndAssignProducts < ActiveRecord::Migration[8.1]
  class MigrationSeller < ActiveRecord::Base
    self.table_name = "sellers"
  end

  def up
    create_table :sellers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :approved_at

      t.timestamps
    end
    add_index :sellers, :slug, unique: true
    add_check_constraint :sellers, "status IN ('pending', 'approved', 'suspended')", name: "sellers_status_check"

    add_reference :users, :seller, foreign_key: true
    add_reference :products, :seller, foreign_key: true

    legacy_seller = MigrationSeller.create!(
      name: "EloShop",
      slug: "eloshop",
      status: "approved",
      approved_at: Time.current
    )
    execute "UPDATE products SET seller_id = #{connection.quote(legacy_seller.id)} WHERE seller_id IS NULL"
    change_column_null :products, :seller_id, false

    remove_index :products, :slug
    remove_index :products, :sku
    add_index :products, %i[seller_id slug], unique: true
    add_index :products, %i[seller_id sku], unique: true

    add_check_constraint :users,
      "(role = 'admin' AND seller_id IS NULL) OR (role = 'seller' AND seller_id IS NOT NULL)",
      name: "users_role_seller_check"
  end

  def down
    remove_check_constraint :users, name: "users_role_seller_check"
    remove_index :products, %i[seller_id sku]
    remove_index :products, %i[seller_id slug]
    add_index :products, :sku, unique: true
    add_index :products, :slug, unique: true
    remove_reference :products, :seller, foreign_key: true
    remove_reference :users, :seller, foreign_key: true
    drop_table :sellers
  end
end
