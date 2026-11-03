# Apaga os tokens do Mercado Pago guardados só para estorno (ateliê
# desconectado ou suspenso) quando não resta venda que o Mercado Pago aceite
# reembolsar. A regra mora em Seller#purge_retained_mercado_pago_credentials!;
# repetir é seguro, porque ateliê já limpo ou ainda dentro do prazo não muda.
class PurgeRetainedMercadoPagoCredentialsJob < ApplicationJob
  queue_as :default

  def perform
    Seller.where.not(mercado_pago_disconnected_at: nil)
      .where.not(mercado_pago_access_token_ciphertext: nil)
      .find_each do |seller|
        next unless seller.purge_retained_mercado_pago_credentials!

        Rails.event.notify("seller.mercado_pago_credentials_purged", seller_id: seller.id)
      end
  end
end
