class AddSellerReplyToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :seller_reply, :text
    add_column :reviews, :seller_replied_at, :datetime
  end
end
