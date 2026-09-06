class AddOriginAddressToSellers < ActiveRecord::Migration[8.1]
  # Endereço de origem do ateliê: de onde a peça é despachada. Nenhum cálculo
  # real de frete funciona sem o CEP de origem, qualquer que seja a
  # transportadora escolhida depois.
  #
  # Nullable de propósito: os vendedores já cadastrados não têm esses dados, e
  # exigi-los na migration deixaria o catálogo deles inválido. A obrigação
  # entra quando o frete real for ligado — decisão de negócio ainda pendente
  # (docs/shipping.md).
  def change
    change_table :sellers, bulk: true do |t|
      t.string :origin_zip_code
      t.string :origin_street
      t.string :origin_number
      t.string :origin_complement
      t.string :origin_neighborhood
      t.string :origin_city
      t.string :origin_state
    end
  end
end
