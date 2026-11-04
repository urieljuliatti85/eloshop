# O retorno do OAuth da SuperFrete é um GET feito pelo servidor dela, não pelo
# navegador do ateliê (observado em produção em 2026-11-04: `axios`, IP do
# Google Cloud) — chega sem a sessão. O `state` pendente sai da sessão e fica
# aqui: só o digest, com o horário de emissão, consumido uma vez no retorno.
# O índice único parcial serve à busca pelo digest e garante que um `state`
# aponte para um ateliê só.
class AddSuperfreteOauthStateToSellers < ActiveRecord::Migration[8.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.string :superfrete_oauth_state_digest
      t.datetime :superfrete_oauth_state_issued_at
    end
    add_index :sellers, :superfrete_oauth_state_digest, unique: true, where: "superfrete_oauth_state_digest IS NOT NULL"
  end
end
