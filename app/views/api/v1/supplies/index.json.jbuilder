json.supplies @products do |product|
  json.partial! "api/v1/supplies/supply", product: product
end
json.page @page
json.total_pages @total_pages
json.total_count @total_count
