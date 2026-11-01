# Segunda faixa do frete definido pelo vendedor: o valor que já existe
# (`fixed_shipping_*`) passa a valer para o mesmo estado do ateliê, e este
# par, opcional, para os demais estados. Sem backfill: vazio significa
# "mesmo valor para todo o Brasil", que é o comportamento de hoje.
class AddInterstateShippingToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :fixed_shipping_interstate_cents, :integer
    add_column :products, :fixed_shipping_interstate_estimated_days, :integer

    add_check_constraint :products,
      "fixed_shipping_interstate_cents IS NULL OR fixed_shipping_interstate_cents > 0",
      name: "products_fixed_shipping_interstate_cents_check"
    add_check_constraint :products,
      "fixed_shipping_interstate_estimated_days IS NULL OR fixed_shipping_interstate_estimated_days > 0",
      name: "products_fixed_shipping_interstate_days_check"
    add_check_constraint :products,
      "(fixed_shipping_interstate_cents IS NULL) = (fixed_shipping_interstate_estimated_days IS NULL)",
      name: "products_fixed_shipping_interstate_complete_check"
    # A faixa interestadual é uma variação da principal, nunca ela sozinha.
    add_check_constraint :products,
      "fixed_shipping_interstate_cents IS NULL OR fixed_shipping_cents IS NOT NULL",
      name: "products_fixed_shipping_interstate_requires_base_check"
  end
end
