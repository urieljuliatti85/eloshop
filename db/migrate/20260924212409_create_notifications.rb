class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :url
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, %i[recipient_type recipient_id read_at]
  end
end
