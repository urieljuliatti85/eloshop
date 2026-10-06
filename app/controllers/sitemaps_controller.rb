class SitemapsController < StorefrontController
  allow_unauthenticated_customer_access

  # Páginas de texto fixo não têm updated_at: a data é a da última vez em que o
  # conteúdo mudou de verdade. Atualize ao editar a view — um lastmod que muda
  # a cada deploy faz o Google parar de confiar no campo.
  STATIC_PAGES_LASTMOD = {
    how_it_works: Time.utc(2026, 10, 6),
    new_seller_registration: Time.utc(2026, 10, 6),
    privacy_policy: Time.utc(2026, 9, 24)
  }.freeze

  def show
    products = Product.publicly_visible
    @products = products.includes(:seller).order(:slug)
    tree = Category::Tree.load(order: :slug)
    @categories = tree.visible
    # Só ateliês com peça publicada: uma vitrine vazia não é conteúdo que
    # valha indexar.
    @sellers = Seller.approved.where(id: products.select(:seller_id)).order(:slug)

    # A listagem muda quando uma peça entra, sai ou é editada, então o lastmod
    # de home, catálogo, categorias e ateliês vem da peça mais recente que
    # eles mostram.
    latest_by_category = products.group("products.category_id").maximum("products.updated_at")
    latest_by_seller = products.group("products.seller_id").maximum("products.updated_at")
    @catalog_lastmod = latest_by_category.values.max
    @category_lastmod = @categories.index_with do |category|
      [ category.updated_at, *latest_by_category.values_at(*tree.self_and_descendant_ids(category)) ].compact.max
    end
    # Sem `seller.updated_at`: o registro do vendedor muda também por renovação
    # de token do Mercado Pago, o que não altera a página pública.
    @seller_lastmod = @sellers.index_with { |seller| latest_by_seller.fetch(seller.id) }

    render layout: false
  end
end
