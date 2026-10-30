module Api
  module V1
    class ProductsController < BaseController
      PER_PAGE = 12
      TEXT_FILTERS = %i[q seller category availability].freeze

      before_action :validate_listing_params, only: :index
      helper_method :sales_open?

      def index
        scope = filtered_scope

        @page = requested_page || 1
        @total_count = scope.count
        @total_pages = (@total_count / PER_PAGE.to_f).ceil
        # Página além da última não vai ao banco: um `page` enorme estouraria
        # o OFFSET (bigint) e respondia 500.
        return @products = Product.none if @page > @total_pages

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

      # Array ou hash na query string (`category[a]=x`, `page[]=1`) chegava ao
      # domínio e respondia 500. Valor desconhecido de `availability`
      # devolvia a listagem sem filtro, e o cliente achava que tinha filtrado:
      # ao contrário do slug de categoria — dado que muda, filtro sem
      # resultado —, os tipos de disponibilidade são um conjunto fechado.
      def validate_listing_params
        invalid = TEXT_FILTERS.find { |name| params.key?(name) && !params[name].is_a?(String) }
        invalid ||= :availability if params[:availability].present? && !Product.availability_types.key?(params[:availability])
        invalid ||= :page if params.key?(:page) && requested_page.nil?

        render_invalid_parameter invalid.to_s if invalid
      end

      # Inteiro positivo; qualquer outra coisa é nil, e o 400 vem da validação.
      def requested_page
        page = Integer(params[:page], 10, exception: false) if params[:page].is_a?(String)
        page if page&.positive?
      end

      # `available_for_purchase?` diz se a peça é vendável; com as vendas da
      # plataforma fechadas (pré-cadastro) a loja ainda recusa o carrinho, e a
      # API não pode prometer o contrário. Lido uma vez por requisição, não por
      # produto da página.
      def sales_open?
        @sales_open = PlatformSetting.sales_open? if @sales_open.nil?
        @sales_open
      end

      # Um subconjunto dos filtros do catálogo do storefront, sobre o mesmo
      # escopo público — a API não enxerga nada que a loja já não mostre.
      def filtered_scope
        scope = Product.publicly_visible
        scope = scope.matching_query(params[:q]) if params[:q].present?
        # `sellers` e não `seller`: `publicly_visible` já faz o join, e a
        # condição precisa apontar para a tabela, não para o alias.
        scope = scope.where(sellers: { slug: params[:seller] }) if params[:seller].present?
        scope = scope.where(category_id: category_ids_for(params[:category])) if params[:category].present?
        scope = scope.where(availability_type: params[:availability]) if params[:availability].present?
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
