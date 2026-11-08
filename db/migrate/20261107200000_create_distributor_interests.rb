# frozen_string_literal: true

class CreateDistributorInterests < ActiveRecord::Migration[8.1]
  def change
    create_table :distributor_interests do |t|
      t.string :email_address, null: false
      t.string :whatsapp_number, null: false
      t.datetime :consent_at, null: false
      t.datetime :notified_at

      t.timestamps
    end

    add_index :distributor_interests, "lower(email_address)", unique: true
    add_index :distributor_interests, :notified_at
  end
end
