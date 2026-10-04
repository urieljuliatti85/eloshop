# Marco de quando o vendedor terminou (ou pulou) o tour guiado do painel. Nulo
# dispara o tour sozinho no primeiro acesso; guardar no servidor, e não no
# navegador, evita repeti-lo em outro aparelho.
#
# Quem já existe quando a coluna nasce está operando o painel: marcar como
# concluído evita interrompê-lo com um tour que não pediu. O botão "Fazer
# tour" continua disponível para todos.
class AddTourCompletedAtToSellers < ActiveRecord::Migration[8.1]
  def up
    add_column :sellers, :tour_completed_at, :datetime
    execute "UPDATE sellers SET tour_completed_at = NOW()"
  end

  def down
    remove_column :sellers, :tour_completed_at
  end
end
