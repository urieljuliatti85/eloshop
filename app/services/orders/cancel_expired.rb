module Orders
  # Cancela pedidos pending cujo PIX expirou há mais de uma hora, devolvendo
  # o estoque debitado no checkout. Peça única (one_of_a_kind) tem sua
  # própria regra de não reativar sold_out automaticamente — devolver
  # stock_quantity não contorna isso, porque Product#available_for_purchase?
  # também depende do status, e a transição de volta a "active" não é
  # disparada aqui.
  class CancelExpired
    GRACE_PERIOD = 1.hour

    def call
      candidate_orders.find_each { |order| cancel_order!(order) }
    end

    private

    def candidate_orders
      Order.pending
        .joins(:payments)
        .where(payments: { status: "pending" })
        .where("payments.expires_at IS NOT NULL AND payments.expires_at <= ?", GRACE_PERIOD.ago)
        .distinct
    end

    def cancel_order!(order)
      order.with_lock do
        next unless order.pending?
        next if order.payments.where(status: %w[authorized paid partially_refunded refunded]).exists?

        restore_stock!(order)
        order.cancel!
      end
    end

    def restore_stock!(order)
      order.order_items.each do |item|
        next if item.product.availability_type_made_to_order?

        if item.product_variant
          item.product_variant.increment!(:stock_quantity, item.quantity)
        else
          item.product.increment!(:stock_quantity, item.quantity)
        end
      end
    end
  end
end
