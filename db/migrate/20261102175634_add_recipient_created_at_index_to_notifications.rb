# O sino (Notification.chronological.limit(5)) roda em toda página do admin e
# da conta do cliente, e a lista de notificações do admin passou a paginar.
# O índice existente (recipient_type, recipient_id, read_at) filtra pelo
# destinatário mas ordena tudo dele em memória: medido no dev com 50 mil
# notificações de um admin, o sino levava 12 ms; com este índice, 0,04 ms.
# O índice antigo continua servindo a contagem de não lidas.
#
# `concurrently` para não travar escrita em notifications durante o deploy.
class AddRecipientCreatedAtIndexToNotifications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_notifications_on_recipient_and_created_at".freeze

  def up
    remove_invalid_index
    add_index :notifications, [ :recipient_type, :recipient_id, :created_at, :id ],
      order: { created_at: :desc, id: :desc },
      name: INDEX_NAME,
      algorithm: :concurrently
  end

  def down
    remove_index :notifications, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end

  private

  # Um CREATE INDEX CONCURRENTLY interrompido (timeout, container derrubado)
  # deixa um índice INVÁLIDO com este nome e não registra a migration: sem
  # isto, todo deploy seguinte falhava no `db:prepare` do boot com
  # PG::DuplicateTable. Só um índice inválido é removido; um válido nunca é
  # tocado. Reproduzido no QA do #306 com statement_timeout.
  def remove_invalid_index
    invalid = select_value(<<~SQL)
      SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
      WHERE c.relname = #{connection.quote(INDEX_NAME)} AND NOT i.indisvalid
    SQL
    remove_index :notifications, name: INDEX_NAME, algorithm: :concurrently if invalid
  end
end
