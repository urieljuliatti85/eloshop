# Marco do início da produção de peças sob encomenda ou personalizadas. Nulo
# até o vendedor marcar (ou até o envio, que implica produção). Sem coluna
# própria, não haveria como provar quando a produção começou numa disputa.
class AddProductionStartedAtToSellerOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :seller_orders, :production_started_at, :datetime
  end
end
