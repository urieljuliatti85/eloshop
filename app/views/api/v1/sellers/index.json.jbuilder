json.sellers @sellers do |seller|
  json.partial! "api/v1/sellers/seller", seller: seller, product_count: @product_counts.fetch(seller.id, 0)
end
