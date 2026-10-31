# Vitrine do pré-cadastro: o admin libera o ateliê para aparecer na loja
# antes de ele conectar o Mercado Pago. Aparecer não é vender — a compra
# continua exigindo aprovação (Seller#approve!).
#
# Aprovar também marca a vitrine, para que desconectar o Mercado Pago só pare
# as vendas em vez de tirar o ateliê do ar. O backfill dá a mesma condição a
# quem já estava aprovado antes desta coluna existir.
class AddShowcasedAtToSellers < ActiveRecord::Migration[8.1]
  def up
    add_column :sellers, :showcased_at, :datetime

    execute <<~SQL
      UPDATE sellers SET showcased_at = approved_at
      WHERE status = 'approved' AND approved_at IS NOT NULL
    SQL
  end

  def down
    remove_column :sellers, :showcased_at
  end
end
