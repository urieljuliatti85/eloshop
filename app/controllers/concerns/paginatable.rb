# Paginação simples via LIMIT/OFFSET nativo do Active Record — sem gem,
# porque o Rails já resolve isso para uma listagem comum (CLAUDE.md, "Rails
# First"). `paginate` devolve o recorte da página atual e expõe `@pagination`
# para a partial de navegação (current_page, total_pages, total_count).
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 15

  Pagination = Struct.new(:current_page, :total_pages, :total_count, :per_page) do
    def first_page? = current_page <= 1
    def last_page? = current_page >= total_pages

    # Números de página a exibir, com nil marcando uma lacuna ("…"): sempre a
    # primeira, a última, e uma janela em torno da página atual — para não
    # listar centenas de páginas quando o total_count é grande.
    def page_window(radius: 2)
      window = ([ 1, total_pages ] + ((current_page - radius)..(current_page + radius)).to_a)
        .select { |page| page.between?(1, total_pages) }
        .uniq
        .sort

      window.each_with_object([]) do |page, result|
        result << nil if result.any? && page - result.last.to_i > 1
        result << page
      end
    end
  end

  private

  def paginate(scope, per_page: DEFAULT_PER_PAGE)
    total_count = scope.count
    total_pages = [ (total_count / per_page.to_f).ceil, 1 ].max
    current_page = requested_page.clamp(1, total_pages)

    @pagination = Pagination.new(current_page, total_pages, total_count, per_page)
    scope.limit(per_page).offset((current_page - 1) * per_page)
  end

  # Recorta um Array já carregado (ex.: uma lista calculada em memória), em
  # vez de uma relação — mesmo contrato de `paginate`, sem tocar o banco.
  def paginate_array(array, per_page: DEFAULT_PER_PAGE)
    total_count = array.size
    total_pages = [ (total_count / per_page.to_f).ceil, 1 ].max
    current_page = requested_page.clamp(1, total_pages)

    @pagination = Pagination.new(current_page, total_pages, total_count, per_page)
    array.slice((current_page - 1) * per_page, per_page) || []
  end

  def requested_page
    Integer(params[:page], exception: false) || 1
  end
end
