class CreateFraudAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :fraud_alerts do |t|
      t.belongs_to :seller, null: false, foreign_key: { on_delete: :cascade }
      t.string :rule, null: false
      t.jsonb :detail, default: {}, null: false
      t.datetime :detected_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    # Um alerta aberto por vendedor e regra: é o que impede o mesmo aviso de
    # se repetir a cada rodada do scan.
    add_index :fraud_alerts, %i[seller_id rule], unique: true, where: "resolved_at IS NULL",
      name: "index_fraud_alerts_one_open_per_seller_rule"
    add_index :fraud_alerts, :resolved_at
  end
end
