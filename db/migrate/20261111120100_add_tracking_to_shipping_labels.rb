# O que a SuperFrete informou sobre a etiqueta depois da compra (webhook ou
# conferência periódica). Fica na etiqueta mesmo quando o envio não pode
# avançar (desistência ou reembolso em andamento): o pacote está com a
# transportadora de qualquer jeito, e `attention_notified_at` garante um só
# aviso à equipe e ao ateliê.
class AddTrackingToShippingLabels < ActiveRecord::Migration[8.1]
  def change
    add_column :shipping_labels, :provider_status, :string
    add_column :shipping_labels, :posted_at, :datetime
    add_column :shipping_labels, :delivered_at, :datetime
    add_column :shipping_labels, :attention_notified_at, :datetime
  end
end
