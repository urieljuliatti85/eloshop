class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :verified_purchase, null: false, default: false

      t.timestamps

      t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_range_check"
    end

    add_index :reviews, [ :customer_id, :product_id ], unique: true
    add_index :reviews, :status
  end
end
