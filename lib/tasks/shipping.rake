# Aviso único depois do deploy do frete definido pelo vendedor: notifica no
# painel os ateliês com produto publicado ainda usando a tabela interna.
#
# Uso: bin/rails shipping:notify_missing
namespace :shipping do
  desc "Avisa no painel os ateliês com produto publicado sem frete definido"
  task notify_missing: :environment do
    notified = Shipping::MissingShippingNotice.call
    puts "Ateliês avisados: #{notified}"
  end
end
