json.id product.id
json.name product.name
json.slug product.slug
json.seller { json.name product.seller.name; json.slug product.seller.slug }
json.description product.description
json.price_cents product.price_cents
json.currency product.currency
json.sale_unit product.sale_unit
json.sale_unit_name product.sale_unit_name
json.sale_unit_detail product.sale_unit_detail
json.min_order_quantity product.min_order_quantity
json.price_tiers product.price_tiers.ordered do |tier|
  json.min_quantity tier.min_quantity
  json.discount_bps tier.discount_bps
  json.price_cents tier.apply_to(product.price_cents)
end
# A compra de insumos só entra na Fase 27.
json.available_for_purchase false
