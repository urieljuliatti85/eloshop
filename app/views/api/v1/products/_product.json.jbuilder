json.id product.id
json.name product.name
json.slug product.slug
json.seller do
  json.name product.seller.name
  json.slug product.seller.slug
end
json.description product.description
json.price_cents product.starting_price_cents
json.currency product.currency
json.availability_type product.availability_type
json.production_time_range product.production_time_range
# Com as vendas da plataforma fechadas (pré-cadastro) a loja recusa o
# carrinho, e a API não pode prometer o contrário. `sales_open?` é o helper
# memoizado da loja (ApplicationHelper): uma leitura por requisição.
json.available_for_purchase sales_open? && product.available_for_purchase?
