module Orders
  # Libera o estoque de pedidos `pending` cuja única tentativa de cobrança ficou
  # `processing`: a criação no gateway falhou ou a resposta se perdeu. Sem isto,
  # `Orders::CancelExpired` nunca os pega (ele só olha cobrança `pending` com
  # validade vencida) e o estoque debitado no checkout fica preso para sempre.
  #
  # O cuidado é não cancelar um pedido cuja cobrança chegou a nascer no gateway
  # (no cartão, o cliente seria cobrado sem pedido). Por isso, antes de cancelar,
  # pergunta ao gateway pelo número do pedido:
  # - achou: guarda o `external_id` e deixa o fluxo normal (webhook e
  #   `Payments::Reconcile`) decidir; não cancela;
  # - não achou: cancela e devolve o estoque, pelo cancelamento de sempre;
  # - não conseguiu perguntar: não faz nada e tenta na próxima rodada.
  #
  # A tentativa `processing` fica como está: `Payment` exige `external_id` fora
  # desse estado, então ela não pode virar `failed` sem ter sido criada.
  class CancelAbandoned
    STALE_AFTER = 1.hour
    LIVE_PAYMENT_STATUSES = %w[pending authorized paid partially_refunded refunded].freeze

    def initialize(gateway: nil)
      @gateway = gateway
    end

    def call
      candidate_orders.find_each { |order| handle(order) }
    end

    private

    def candidate_orders
      Order.pending
        .where(id: Payment.processing.where(payments: { created_at: ..STALE_AFTER.ago }).select(:order_id))
        .where.not(id: Payment.processing.where(payments: { created_at: STALE_AFTER.ago.. }).select(:order_id))
        .where.not(id: Payment.where(status: LIVE_PAYMENT_STATUSES).select(:order_id))
    end

    def handle(order)
      latest = order.payments.processing.order(:created_at).last
      remote = (@gateway || Gateways.build(latest.gateway)).find_payment_for(order: order)

      if remote
        recover(latest, remote)
      else
        cancel(order)
      end
    rescue Gateways::MercadoPago::RequestFailed, Gateways::MercadoPago::ConfigurationError => e
      Rails.event.notify("order.abandoned_check_failed", order_id: order.id, error: e.class.name)
    end

    def recover(payment, remote)
      payment.update!(external_id: remote.external_id, status: "pending")
      Rails.event.notify("order.abandoned_payment_recovered", order_id: payment.order_id, payment_id: payment.id)
    end

    def cancel(order)
      Cancel.new.call(order)
      Rails.event.notify("order.abandoned_cancelled", order_id: order.id)
    rescue Cancel::InvalidCancellation
      # Mudou de estado entre a consulta e o cancelamento: não é erro do job.
      nil
    end
  end
end
