# Lembrete de carrinho esquecido: o cliente pode recusar (default: aceita, com
# descadastro em todo e-mail) e o carrinho guarda quando o último lembrete saiu,
# para nunca mandar mais de um por período de abandono.
class AddCartReminderColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :cart_reminder_emails, :boolean, default: true, null: false
    add_column :carts, :reminder_sent_at, :datetime
  end
end
