module Gateways
  # Cobrança que já existe no gateway, achada pelo número do pedido. Serve para
  # saber se uma tentativa que ficou `processing` (resposta perdida) chegou a
  # nascer do outro lado.
  RemotePayment = Data.define(:external_id, :status)
end
