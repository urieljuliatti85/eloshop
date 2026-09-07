module Shipping
  # Uma opção de frete, no vocabulário do domínio e não no de um provedor.
  # É o que `Shipment` grava e o que o checkout apresenta ao cliente.
  #
  # `id` identifica a opção escolhida entre as ofertadas. Não é o id do
  # provedor: o servidor recalcula a cotação no checkout e reencontra a opção
  # por esta chave, então ela precisa ser estável entre a exibição e a
  # confirmação — carrier + service dão isso, e não dependem de o provedor
  # manter o mesmo id entre duas chamadas.
  Quote = Data.define(:carrier, :service, :shipping_cents, :estimated_days) do
    def id
      "#{carrier}|#{service}".parameterize
    end
  end
end
