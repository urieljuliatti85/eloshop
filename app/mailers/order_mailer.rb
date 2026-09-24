class OrderMailer < ApplicationMailer
  # Confirmação para quem comprou. Enviado quando o pagamento é aprovado,
  # nunca na criação do pedido: até o pagamento confirmar, não há compra.
  def confirmation(order)
    @order = order
    @seller = order.seller_order.seller

    mail(
      to: order.customer.email,
      subject: "Pedido ##{order.id} confirmado — EloShop"
    )
  end

  # Aviso ao artesão de que vendeu. Vai para o e-mail do `User` do papel
  # `seller` vinculado ao ateliê; um ateliê sem usuário não recebe nada
  # (o job trata esse caso antes de chamar aqui).
  def seller_notification(seller_order, recipient)
    @seller_order = seller_order
    @order = seller_order.order
    @seller = seller_order.seller

    mail(
      to: recipient,
      subject: "Nova venda: pedido ##{@order.id} — EloShop"
    )
  end

  # Avisa o artesão de que o comprador confirmou o recebimento do pedido,
  # pelo lado do cliente (não pelo painel do vendedor).
  def delivery_confirmed_by_customer(seller_order, recipient)
    @seller_order = seller_order
    @order = seller_order.order
    @seller = seller_order.seller

    mail(
      to: recipient,
      subject: "Pedido ##{@order.id} confirmado como entregue pelo cliente — EloShop"
    )
  end

  # Avisa o cliente de que o vendedor confirmou a entrega pelo painel —
  # aviso inverso de delivery_confirmed_by_customer.
  def delivery_confirmed_by_seller(seller_order)
    @seller_order = seller_order
    @order = seller_order.order
    @seller = seller_order.seller

    mail(
      to: @order.customer.email,
      subject: "Pedido ##{@order.id} marcado como entregue — EloShop"
    )
  end
end
