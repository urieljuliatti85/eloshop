# Registra a venda no log estruturado que a Fase 19 montou (`Rails.event`),
# pesquisável no Log Explorer da Railway — mesma instrumentação que localizou
# o gargalo do catálogo na Fase 17.
#
# Só dado de negócio agregável: nada de nome, e-mail ou endereço do cliente
# (CLAUDE.md §43). O `customer_id` basta para correlacionar sem expor pessoa.
class RecordOrderAnalyticsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(order)
    seller_order = order.seller_order

    Rails.event.notify(
      "order.confirmed",
      order_id: order.id,
      customer_id: order.customer_id,
      seller_id: seller_order.seller_id,
      seller_slug: seller_order.seller.slug,
      item_count: order.order_items.sum(:quantity),
      subtotal_cents: order.subtotal_cents,
      discount_cents: order.discount_cents,
      shipping_cents: order.shipping_cents,
      total_cents: order.total_cents,
      platform_fee_cents: seller_order.platform_fee_cents,
      seller_amount_cents: seller_order.seller_amount_cents,
      currency: seller_order.currency,
      coupon_id: order.coupon_id
    )
  end
end
