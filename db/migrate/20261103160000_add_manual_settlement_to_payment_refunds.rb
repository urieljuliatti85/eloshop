# Reembolso feito por fora do Mercado Pago (transferência ou PIX direto ao
# comprador) quando o provedor não consegue: ateliê sem saldo no split 1:1 ou
# pagamento com mais de 180 dias. Registrado pelo admin, passa pela mesma
# contabilidade do reembolso pelo gateway. As restrições garantem no banco
# que todo reembolso manual diz quem lançou e qual o comprovante.
class AddManualSettlementToPaymentRefunds < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_refunds, :settlement, :string, default: "gateway", null: false
    add_column :payment_refunds, :manual_reference, :text
    add_reference :payment_refunds, :recorded_by, foreign_key: { to_table: :users }, index: true

    add_check_constraint :payment_refunds, "settlement IN ('gateway', 'manual')", name: "payment_refunds_settlement_check"
    add_check_constraint :payment_refunds,
      "settlement <> 'manual' OR (recorded_by_id IS NOT NULL AND char_length(btrim(manual_reference)) BETWEEN 3 AND 500)",
      name: "payment_refunds_manual_proof_check"
  end
end
