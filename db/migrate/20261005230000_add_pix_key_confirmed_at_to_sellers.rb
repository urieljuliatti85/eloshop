# Marco de quando o vendedor declarou ter uma chave PIX cadastrada na conta do
# Mercado Pago. Sem a chave, o MP recusa a cobrança PIX (400 "Collector user
# without key enabled for QR render"), e a API não permite consultar isso: é a
# palavra do vendedor, usada só para tirar o aviso do painel. Nulo = não
# confirmou; ninguém é marcado retroativamente, para o aviso chegar a todos.
class AddPixKeyConfirmedAtToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :pix_key_confirmed_at, :datetime
  end
end
