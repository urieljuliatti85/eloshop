class HomeController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    categories = Category.order(:name).to_a
    @categories = categories.select { |category| category.parent_id.nil? }

    # A categoria não tem imagem própria (não há necessidade de negócio para
    # mais um upload — CLAUDE.md §5): a capa é a foto do produto ativo mais
    # recente da categoria ou de alguma subcategoria dela.
    descendants = descendant_ids_by_category(categories)
    @category_covers = @categories.index_with do |category|
      cover_product_for(descendants.fetch(category.id))
    end
  end

  private

  # Category#self_and_descendant_ids consulta `children` a cada nível da
  # recursão: na home, com 3 categorias de topo, isso custava 22 queries. Aqui
  # a árvore inteira vem em uma leitura e é percorrida em memória.
  def descendant_ids_by_category(categories)
    children = categories.group_by(&:parent_id)

    categories.index_by(&:id).transform_values do |category|
      ids = [ category.id ]
      queue = [ category.id ]

      until queue.empty?
        Array(children[queue.shift]).each do |child|
          ids << child.id
          queue << child.id
        end
      end

      ids
    end
  end

  def cover_product_for(category_ids)
    Product.active
      .where(category_id: category_ids)
      .where.associated(:main_image_attachment)
      .with_attached_main_image
      .order(created_at: :desc)
      .first
  end
end
