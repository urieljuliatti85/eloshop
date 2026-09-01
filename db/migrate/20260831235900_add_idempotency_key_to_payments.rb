class AddIdempotencyKeyToPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :idempotency_key, :string

    execute <<~SQL.squish
      UPDATE payments
      SET idempotency_key = 'legacy-' || id::text
      WHERE idempotency_key IS NULL
    SQL

    change_column_null :payments, :idempotency_key, false
    change_column_null :payments, :external_id, true
    add_index :payments, :idempotency_key, unique: true
  end

  def down
    remove_index :payments, :idempotency_key
    execute <<~SQL.squish
      UPDATE payments
      SET external_id = 'rolled-back-' || id::text
      WHERE external_id IS NULL
    SQL
    change_column_null :payments, :external_id, false
    remove_column :payments, :idempotency_key
  end
end
