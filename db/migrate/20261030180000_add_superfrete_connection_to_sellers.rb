# Conexão do ateliê com a SuperFrete (ADR 005, segundo provedor). O token não
# expira nem tem refresh (documentação oficial: `"expires": "never"`), por
# isso não há colunas de refresh/expiração como no Melhor Envio. A conta vem
# de `GET /api/v0/user` logo depois do OAuth: a troca do token não a devolve,
# e é ela que diz ao ateliê qual carteira paga as etiquetas.
#
# `provider_quotes_preferred` é a escolha do ateliê entre a cotação do
# provedor e o frete que ele definiu no produto. Nasce falso: vale o frete do
# ateliê, como nos termos comerciais, até ele optar pela cotação.
class AddSuperfreteConnectionToSellers < ActiveRecord::Migration[8.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.text :superfrete_access_token_ciphertext
      t.string :superfrete_account_id
      t.string :superfrete_account_email
      t.datetime :superfrete_connected_at
      t.boolean :superfrete_sandbox, default: false, null: false
      t.boolean :provider_quotes_preferred, default: false, null: false
    end
  end
end
