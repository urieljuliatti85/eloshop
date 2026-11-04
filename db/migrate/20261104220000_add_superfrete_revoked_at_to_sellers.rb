# O token da SuperFrete não expira: um 401 na cotação quer dizer que o ateliê
# removeu a integração do lado de lá. Até aqui isso só virava um evento, e o
# ateliê continuava "conectado". Com a conexão obrigatória para aprovar, o
# "conectado" precisa ser verdade: o 401 grava esta data, e a etapa e a
# cotação deixam de contar a conexão até ele reconectar.
class AddSuperfreteRevokedAtToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :superfrete_revoked_at, :datetime
  end
end
