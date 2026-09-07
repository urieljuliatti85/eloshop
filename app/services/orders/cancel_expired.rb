module Orders
  # Cancela pedidos pending cujo PIX expirou há mais de uma hora. A regra de
  # cancelamento em si (transição de status + devolução de estoque) é
  # Orders::Cancel — aqui só decide quais pedidos são candidatos.
  class CancelExpired
    GRACE_PERIOD = 1.hour

    def call
      candidate_orders.find_each do |order|
        Cancel.new.call(order)
      rescue Cancel::InvalidCancellation
        # Pedido mudou de estado entre a consulta e a tentativa de cancelar
        # (ex.: pagamento confirmou no meio do job) — não é um erro do job.
        next
      end
    end

    private

    def candidate_orders
      Order.pending
        .joins(:payments)
        .where(payments: { status: "pending" })
        .where("payments.expires_at IS NOT NULL AND payments.expires_at <= ?", GRACE_PERIOD.ago)
        .distinct
    end
  end
end
