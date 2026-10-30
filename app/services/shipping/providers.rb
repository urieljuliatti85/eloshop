module Shipping
  # Provedores de cotação de frete. Cada ateliê conecta no máximo um; o
  # `Shipping::Calculator` pergunta aqui qual é, em vez de conhecer cada
  # provedor pelo nome.
  module Providers
    # Falha de qualquer provedor: o Calculator registra e segue com o frete do
    # ateliê ou a tabela interna — a cotação real nunca derruba o checkout.
    class Unavailable < StandardError; end

    # O provedor conectado pelo ateliê, ou nil quando ele não conectou nenhum
    # ou quando as cotações externas estão desligadas neste ambiente.
    def self.for(seller)
      return unless enabled?
      return unless seller

      MelhorEnvio.new(seller: seller) if seller.melhor_envio_connected?
    end

    # Chave por ambiente (`config.x.shipping.remote_quotes_enabled`). Em
    # produção nasce desligada: sem ela, um ateliê conectado a um app de
    # sandbox passaria a cobrar preço de teste no dia em que o provedor
    # aceitasse as chamadas — e o frete do ateliê é a regra do lançamento.
    def self.enabled?
      Rails.configuration.x.shipping.remote_quotes_enabled == true
    end
  end
end
