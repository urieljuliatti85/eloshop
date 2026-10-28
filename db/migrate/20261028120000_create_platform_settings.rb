# Configuração da plataforma em uma linha só. Nasce com as vendas fechadas
# (`sales_opened_at` nulo): o pré-cadastro deixa o artesão montar a loja antes
# da abertura, e quem abre é o admin, uma vez, pelo dashboard. A data — e não
# um booleano — porque a comissão de lançamento conta a partir dela.
class CreatePlatformSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_settings do |t|
      t.datetime :sales_opened_at
      t.timestamps
    end

    add_check_constraint :platform_settings, "id = 1", name: "platform_settings_singleton_check"
  end
end
