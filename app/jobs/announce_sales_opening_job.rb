# Avisa cada ateliê que aparece na loja (`Seller.publicly_listed`: aprovado ou
# liberado na vitrine) de que as vendas abriram — escondido pelo antifraude não
# é convidado a divulgar uma página fora do ar. Quem está só na vitrine recebe
# outro e-mail, pedindo o Mercado Pago (ver NotifySellerOfSalesOpeningJob). Um
# job por vendedor: se um envio falhar, o retry repete só aquele e-mail, não o
# de todos.
#
# Se o enfileiramento falhar logo depois de `PlatformSetting.open_sales!`, o
# botão do admin não repete o aviso; rode este job à mão (`railway ssh` +
# `bin/rails runner "AnnounceSalesOpeningJob.perform_later"`).
class AnnounceSalesOpeningJob < ApplicationJob
  queue_as :default

  def perform
    Seller.publicly_listed.find_each { |seller| NotifySellerOfSalesOpeningJob.perform_later(seller) }
  end
end
