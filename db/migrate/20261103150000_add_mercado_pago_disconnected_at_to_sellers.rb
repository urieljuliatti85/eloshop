# Desconectar ou suspender o ateliê deixa de apagar os tokens do Mercado Pago:
# eles ficam guardados (cifrados) só para estornar vendas já feitas, até o
# prazo de reembolso do Mercado Pago passar. Esta data separa "conectado para
# cobrar" de "credencial guardada para estorno". Nula em todo ateliê existente
# — quem já desconectou antes não tem token para guardar.
class AddMercadoPagoDisconnectedAtToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :mercado_pago_disconnected_at, :datetime
  end
end
