# Cupom da plataforma vale só para um tipo de vendedor (ADR 007, "Cupom da
# plataforma — só para ateliê"). O desconto sai do repasse de quem vende, então
# um cupom pensado para peça artesanal não pode alcançar pedido de insumo:
# todo cupom existente e todo cupom novo nascem só para ateliê.
class AddSellerKindToCoupons < ActiveRecord::Migration[8.1]
  def change
    add_column :coupons, :seller_kind, :string, null: false, default: "atelier"
    add_check_constraint :coupons, "seller_kind IN ('atelier', 'distributor')", name: "coupons_seller_kind_check"
  end
end
