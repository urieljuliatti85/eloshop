module Api
  module V1
    class ProductsController < BaseController
      PER_PAGE = 12

      def index
        scope = filtered_scope

        @page = [ params[:page].to_i, 1 ].max
        @total_count = scope.count
        @total_pages = (@total_count / PER_PAGE.to_f).ceil
        # `preload`, não `includes`: com anexos do Active Storage o JOIN único
        # infla o custo estimado do plano e dispara o JIT do PostgreSQL — ver
        # o comentário em app/controllers/products_controller.rb.
        # `category: :parent` porque `available_for_purchase?` pergunta se a
        # categoria está visível, e isso sobe a árvore — sem preload era uma
        # query por nível, por produto (medido: 15 numa página de 12).
        @products = scope.preload(:seller, :product_variants, category: :parent)
          .order(created_at: :desc)
          .limit(PER_PAGE)
          .offset((@page - 1) * PER_PAGE)
      end

      def show
        seller = Seller.approved.find_by!(slug: params[:seller_slug])
        @product = seller.products.publicly_visible.includes(:product_variants, category: :parent).find_by!(slug: params[:slug])
      end

      private

      # Um subconjunto dos filtros do catálogo do storefront, sobre o mesmo
      # escopo público — a API não enxerga nada que a loja já não mostre.
      def filtered_scope
        scope = Product.publicly_visible
        scope = scope.matching_query(params[:q]) if params[:q].present?
        # `sellers` e não `seller`: `publicly_visible` já faz o join, e a
        # condição precisa apontar para a tabela, não para o alias.
        scope = scope.where(sellers: { slug: params[:seller] }) if params[:seller].present?
        scope = scope.where(category_id: category_ids_for(params[:category])) if params[:category].present?
        scope = scope.where(availability_type: params[:availability]) if Product.availability_types.key?(params[:availability])
        scope.distinct
      end

      # Uma categoria pai também devolve os produtos das subcategorias, igual
      # ao catálogo. Slug inexistente devolve lista vazia, não 404: é filtro,
      # não recurso.
      def category_ids_for(slug)
        category = Category.find_by(slug: slug)
        return [] unless category

        Category::Tree.load.self_and_descendant_ids(category)
      end
    end
  end
end
