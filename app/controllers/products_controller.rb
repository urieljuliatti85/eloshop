class ProductsController < StorefrontController
  # Quantos produtos por página o cliente pode escolher na vitrine ("Mostrar").
  # Lista fechada: o valor vem da query string e vira LIMIT.
  PER_PAGE_OPTIONS = [ 8, 12, 16, 24 ].freeze
  PER_PAGE = 12

  # "Ordenar por" — também lista fechada, porque o valor vira ORDER BY.
  SORT_OPTIONS = {
    "recentes" => { label: "Novidades", order: { created_at: :desc } },
    "menor-preco" => { label: "Menor preço", order: { price_cents: :asc } },
    "maior-preco" => { label: "Maior preço", order: { price_cents: :desc } },
    "nome" => { label: "Nome (A–Z)", order: { name: :asc } }
  }.freeze
  DEFAULT_SORT = "recentes"

  allow_unauthenticated_customer_access

  def index
    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : PER_PAGE

    scope = Product.active.order(SORT_OPTIONS.fetch(@sort)[:order])
    @categories = Category.order(:name)
    @tags = Tag.order(:name)
    @materials = Material.order(:name)
    @techniques = Technique.order(:name)
    @category = Category.find_by!(slug: params[:category]) if params[:category].present?
    scope = scope.where(category_id: @category.self_and_descendant_ids) if @category
    scope = scope.matching_query(params[:q]) if params[:q].present?
    scope = scope.joins(:tags).where(tags: { slug: params[:tag] }) if params[:tag].present?
    scope = scope.joins(:materials).where(materials: { slug: params[:material] }) if params[:material].present?
    scope = scope.joins(:techniques).where(techniques: { slug: params[:technique] }) if params[:technique].present?
    scope = scope.where(availability_type: params[:availability]) if Product.availability_types.key?(params[:availability])
    scope = scope.where("price_cents >= ?", params[:min_price].to_i) if params[:min_price].present?
    scope = scope.where("price_cents <= ?", params[:max_price].to_i) if params[:max_price].present?
    scope = scope.where.not(personalization_options: { id: nil }).joins(:personalization_options) if params[:personalizable] == "1"
    scope = scope.distinct

    @total_count = scope.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    @page = [ params[:page].to_i, 1 ].max
    @products = scope
      # :category entra porque o card do produto mostra o nome da categoria —
      # sem isso é uma query por card (medido: 7 no catálogo com 10 produtos).
      .includes(:product_variants, :personalization_options, category: :parent)
      .with_attached_main_image
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
  end

  def show
    # category: :parent porque a PDP usa breadcrumb_name, que sobe a árvore de
    # categorias — cada nível seria outra query.
    @product = Product.active.includes(:product_variants, category: :parent).find_by!(slug: params[:slug])
    @related_products = @product.related_products
      .includes(:product_variants, :personalization_options, category: :parent)
      .with_attached_main_image
    @reviews = @product.approved_reviews.includes(:customer)
    @existing_review = customer_authenticated? ? @product.reviews.find_by(customer: Current.customer) : nil
  end
end
