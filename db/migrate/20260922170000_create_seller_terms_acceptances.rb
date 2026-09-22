class CreateSellerTermsAcceptances < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_terms_acceptances do |t|
      t.bigint :user_id, null: false
      t.bigint :seller_id, null: false
      t.string :terms_version, null: false
      t.text :terms_text, null: false
      t.string :terms_digest, null: false
      t.datetime :accepted_at, null: false
      t.string :ip_address, null: false
      t.text :user_agent
      t.timestamps
    end

    add_foreign_key :seller_terms_acceptances, :users
    add_foreign_key :seller_terms_acceptances, :sellers
    add_index :seller_terms_acceptances, %i[user_id terms_version], unique: true
    add_index :seller_terms_acceptances, :seller_id
  end
end
