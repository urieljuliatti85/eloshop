module Orders
  # Cancela um pedido pending ou confirmed e devolve o estoque debitado no
  # checkout. Compartilhado pelo cancelamento manual (admin/vendedor) e pelo
  # automático por PIX expirado (Orders::CancelExpired).
  #
  # Peça única (one_of_a_kind) tem sua própria regra de não reativar sold_out
  # automaticamente — devolver stock_quantity não contorna isso, porque
  # Product#available_for_purchase? também depende do status, e a transição
  # de volta a "active" não é disparada aqui.
  class Cancel
    class InvalidCancellation < StandardError; end

    def call(order)
      order.with_lock do
        unless order.pending? || order.confirmed?
          raise InvalidCancellation, "só é possível cancelar pedidos pendentes ou confirmados"
        end

        if order.payments.where(status: %w[authorized paid partially_refunded refunded]).exists?
          raise InvalidCancellation, "este pedido já tem pagamento autorizado — use reembolso"
        end

        restore_stock!(order)
        order.cancel!
      end
    end

    private

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
