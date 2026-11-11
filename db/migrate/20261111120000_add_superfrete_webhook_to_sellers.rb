# Webhook de rastreio da SuperFrete, um por conta de ateliê (ADR 005). A
# SuperFrete não tem webhook único do app OAuth: cada conta registra o seu, e
# o `secret_token` que assina as notificações só aparece na criação.
#
# * `superfrete_webhook_key`: identificador aleatório na URL, para achar o
#   ateliê (e o segredo) antes de verificar a assinatura. Não é segredo: quem
#   autentica é o HMAC.
# * `superfrete_webhook_secret_ciphertext`: o `secret_token`, cifrado como o
#   token de acesso.
# * `superfrete_webhook_id`: para apagar o webhook antigo ao trocar.
class AddSuperfreteWebhookToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :superfrete_webhook_id, :string
    add_column :sellers, :superfrete_webhook_key, :string
    add_column :sellers, :superfrete_webhook_secret_ciphertext, :text
    add_index :sellers, :superfrete_webhook_key, unique: true, where: "superfrete_webhook_key IS NOT NULL"
  end
end
