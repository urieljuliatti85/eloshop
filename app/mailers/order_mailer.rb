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

  # Avisa o artesão de que o comprador reportou o recebimento do pedido —
  # deliberadamente "reportado", não "confirmado": é um sinal do cliente,
  # não o fechamento oficial da entrega, que continua exclusivo do vendedor
  # (Shipment#mark_delivered!, ver comentário no model).
  def delivery_reported_by_customer(seller_order, recipient)
    @seller_order = seller_order
    @order = seller_order.order
    @seller = seller_order.seller

    mail(
      to: recipient,
      subject: "Pedido ##{@order.id}: cliente avisou que recebeu — EloShop"
    )
  end

  # Avisa o cliente de que o vendedor despachou o pedido (Shipment#mark_shipped!).
  # Não é o mesmo aviso de entrega: aqui o pedido só saiu do ateliê, ainda em
  # trânsito — delivery_confirmed_by_seller é quem fecha oficialmente.
  def shipped(seller_order)
    @seller_order = seller_order
    @order = seller_order.order
    @seller = seller_order.seller
    @shipment = seller_order.shipment

    mail(
      to: @order.customer.email,
      subject: "Pedido ##{@order.id} #{@shipment.local_pickup? ? "pronto para retirada" : "enviado"} — EloShop"
    )
  end

  # Avisa o cliente de que o vendedor confirmou a entrega pelo painel — este
  # sim é o fechamento oficial, aviso inverso de delivery_reported_by_customer.
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
