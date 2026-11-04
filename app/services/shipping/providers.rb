module Shipping
  # Provedores de cotação de frete. Hoje só a SuperFrete (o Melhor Envio foi
  # removido em 2026-10-30: só libera IP fixo, exclusivo e brasileiro, que a
  # Railway não oferece). O `Shipping::Calculator` pergunta aqui qual é, em
  # vez de conhecer o provedor pelo nome.
  module Providers
    # Falha de qualquer provedor: o Calculator registra e segue com o frete do
    # ateliê ou a tabela interna — a cotação real nunca derruba o checkout.
    class Unavailable < StandardError; end

    # O provedor conectado pelo ateliê, ou nil quando ele não conectou nenhum,
    # quando conectou em outro ambiente (sandbox x produção) ou quando as
    # cotações externas estão desligadas neste ambiente.
    def self.for(seller)
      return unless enabled?
      return unless seller

      Superfrete.new(seller: seller) if seller.superfrete_ready?
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
