# O Melhor Envio sai da EloShop (2026-10-30): só libera IP fixo, exclusivo e
# brasileiro, que a Railway não oferece, e nunca cotou em produção. A
# SuperFrete o substitui (ADR 005). Os tokens gravados até aqui eram de
# sandbox e não têm uso; o `down` recria as colunas vazias.
class RemoveMelhorEnvioFromSellers < ActiveRecord::Migration[8.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.remove :melhor_envio_access_token_ciphertext, type: :text
      t.remove :melhor_envio_refresh_token_ciphertext, type: :text
      t.remove :melhor_envio_token_expires_at, type: :datetime
      t.remove :melhor_envio_connected_at, type: :datetime
      t.remove :melhor_envio_sandbox, type: :boolean, default: false, null: false
    end
  end
end
