# Destinatário do pedido (ADR 005, "Etapa 2 e 3"): a etiqueta da SuperFrete
# exige nome e CPF de quem recebe. Colunas anuláveis: pedidos anteriores e os
# de retirada no ateliê não têm CPF. O CPF fica cifrado (Order#recipient_cpf=).
class AddRecipientToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :recipient_name, :string
    add_column :orders, :recipient_phone, :string
    add_column :orders, :recipient_cpf_ciphertext, :text
  end
end
