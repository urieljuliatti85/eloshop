json.products @products do |product|
  json.partial! "api/v1/products/product", product: product
end
json.page @page
json.total_pages @total_pages
