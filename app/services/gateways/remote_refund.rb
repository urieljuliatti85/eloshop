module Gateways
  # Reembolso que já existe no gateway, listado a partir do pagamento. Serve
  # para resolver uma tentativa que ficou `processing` (resposta perdida ou
  # reembolso em contingência, comum no PIX). `status` já vem no vocabulário
  # do domínio: approved / processing / failed.
  RemoteRefund = Data.define(:external_id, :status, :amount_cents)
end
