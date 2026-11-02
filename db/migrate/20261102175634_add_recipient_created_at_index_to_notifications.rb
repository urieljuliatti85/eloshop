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

  def change
    add_index :notifications, [ :recipient_type, :recipient_id, :created_at, :id ],
      order: { created_at: :desc, id: :desc },
      name: "index_notifications_on_recipient_and_created_at",
      algorithm: :concurrently
  end
end
