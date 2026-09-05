class HomeController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    tree = Category::Tree.load
    @categories = tree.visible_roots

    # A categoria não tem imagem própria (não há necessidade de negócio para
    # mais um upload — CLAUDE.md §5): a capa é a foto do produto ativo mais
    # recente da categoria ou de alguma subcategoria dela.
    @category_covers = cover_products_by_category(tree)

    # "Destaque" aqui é só "recente": nenhuma curadoria manual existe ainda, e
    # não há necessidade de negócio confirmada para um campo de seleção
    # editorial no Product. Sem exigir imagem: ausência de foto já é tratada
    # no `_product_card`, e excluir aqui reduziria demais o catálogo no
    # começo de uma loja com poucos produtos.
    @featured_products = Product.publicly_visible
      .order(created_at: :desc)
      .limit(6)
      .preload(:seller, :product_variants)
      .preload(main_image_attachment: :blob)
  end

  private

  # Duas leituras fixas, independentes do número de categorias de topo: uma
  # escolhe as capas, a outra carrega as escolhidas já com o anexo.
  #
  # Antes era uma busca por categoria, e cada uma arrastava o anexo, o blob e
  # os variant records atrás de si — 5 queries por categoria (medido: 18 na
  # home com 3 categorias de topo, +5 a cada categoria nova).
  def cover_products_by_category(tree)
    subtrees = @categories.index_with { |category| tree.self_and_descendant_ids(category) }
    newest = newest_product_by_category(subtrees.values.flatten.uniq)

    cover_ids = subtrees.transform_values do |category_ids|
      category_ids.filter_map { |id| newest[id] }.max_by(&:created_at)&.id
    end

    covers = Product.where(id: cover_ids.values.compact).includes(:seller).with_attached_main_image.index_by(&:id)
    cover_ids.transform_values { |id| covers[id] }
  end

  # DISTINCT ON devolve no máximo uma linha por categoria: o custo acompanha o
  # número de categorias, não o tamanho do catálogo. A escolha entre as
  # candidatas de uma subárvore é feita em memória porque "categoria de topo"
  # é uma relação transitiva, que o GROUP BY não alcança.
  def newest_product_by_category(category_ids)
    Product.publicly_visible
      .where(category_id: category_ids)
      .where.associated(:main_image_attachment)
      .select("DISTINCT ON (products.category_id) products.id, products.category_id, products.created_at")
      .order("products.category_id", "products.created_at DESC")
      .index_by(&:category_id)
  end
end
