module SellerPortal::OrdersHelper
  FULFILLMENT_BADGE_CLASSES = {
    awaiting_payment: "bg-stone-100 text-stone-700",
    preparing: "bg-amber-100 text-amber-800",
    shipped: "bg-sky-100 text-sky-800",
    ready_for_pickup: "bg-sky-100 text-sky-800",
    delivered: "bg-emerald-100 text-emerald-800",
    picked_up: "bg-emerald-100 text-emerald-800",
    closed: "bg-stone-100 text-stone-600",
    unavailable: "bg-stone-100 text-stone-600"
  }.freeze

  def seller_order_fulfillment_state(seller_order)
    return :closed if seller_order.cancelled? || seller_order.refunded?
    return :awaiting_payment if seller_order.pending?

    shipment = seller_order.shipment
    return :unavailable unless shipment
    return shipment.local_pickup? ? :picked_up : :delivered if shipment.delivered?
    return shipment.local_pickup? ? :ready_for_pickup : :shipped if shipment.shipped?

    :preparing
  end

  def seller_order_fulfillment_label(seller_order)
    t(seller_order_fulfillment_state(seller_order), scope: "shipments.fulfillment_states")
  end

  def seller_order_fulfillment_badge_classes(seller_order)
    FULFILLMENT_BADGE_CLASSES.fetch(seller_order_fulfillment_state(seller_order))
  end

  def seller_order_timeline_steps(seller_order)
    shipment = seller_order.shipment
    pickup = shipment&.local_pickup?
    current_step = fulfillment_current_step(seller_order)

    [
      { label: "Pedido recebido", time: seller_order.order.created_at },
      { label: "Em preparação", time: nil },
      { label: pickup ? "Pronto para retirada" : "Enviado", time: shipment&.shipped_at },
      { label: pickup ? "Retirado" : "Entregue", time: shipment&.delivered_at }
    ].each_with_index.map do |step, index|
      step.merge(state: timeline_step_state(index, current_step))
    end
  end

  private

  def fulfillment_current_step(seller_order)
    return 0 if seller_order.pending? || seller_order.cancelled? || seller_order.refunded?

    shipment = seller_order.shipment
    return 1 unless shipment
    return 3 if shipment.delivered?
    return 2 if shipment.shipped?

    1
  end

  def timeline_step_state(index, current_step)
    return :complete if index < current_step
    return :current if index == current_step

    :upcoming
  end
end
