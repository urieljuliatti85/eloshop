json.categories @categories do |category|
  json.name category.name
  json.slug category.slug
  json.breadcrumb_name @tree.breadcrumb_name(category)
  json.parent_slug @tree.parent(category)&.slug
  # Só os produtos da própria categoria: a soma da subárvore mudaria o
  # significado do número entre pai e filha.
  json.product_count @product_counts.fetch(category.id, 0)
end
