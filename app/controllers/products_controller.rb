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

    scope = Product.publicly_visible.order(SORT_OPTIONS.fetch(@sort)[:order])
    # A árvore inteira em uma leitura: o filtro lateral mostra o breadcrumb de
    # cada categoria, e resolver isso pelo Active Record custava uma query por
    # nível, por categoria (medido: 5 das 24 queries do catálogo filtrado).
    @category_tree = Category::Tree.load
    @categories = @category_tree.visible
    @tags = Tag.order(:name)
    @materials = Material.order(:name)
    @techniques = Technique.order(:name)
    @category = find_category!(params[:category]) if params[:category].present?
    scope = scope.where(category_id: @category_tree.self_and_descendant_ids(@category)) if @category
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
      #
      # preload, e não includes, porque aqui já existe `distinct`: com includes
      # o Active Record resolve tudo numa única SELECT DISTINCT, e a capa
      # (main_image) arrasta as tabelas de variante do Active Storage, dando
      # 15 JOINs e ~130 colunas. Isso não torna a execução lenta — o Unique
      # roda em 0,03 ms —, mas infla o custo *estimado* do plano para 2,5M
      # (estimativa de 985.759 linhas para devolver 12), o que ultrapassa o
      # jit_above_cost do PostgreSQL: o banco compila 120 funções por
      # execução, ~1240 ms, a cada requisição (JIT não é cacheado).
      # Medido em produção: /produtos a 1012 ms (p50). Com preload, cada
      # associação vira sua própria query pequena, o plano nunca chega ao
      # limiar do JIT e a ação cai para ~10 ms.
      .preload(:seller, :product_variants, :personalization_options, category: :parent)
      .preload(main_image_attachment: :blob)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
      # A view pergunta `@products.any?` antes de renderizar a grade; sem
      # carregar aqui, isso vira um SELECT ... LIMIT 1 a mais por página.
      .load
  end

  def show
    # category: :parent porque a PDP usa breadcrumb_name, que sobe a árvore de
    # categorias — cada nível seria outra query.
    seller = Seller.approved.find_by!(slug: params[:seller_slug])
    @product = seller.products.publicly_visible.includes(:product_variants, category: :parent).find_by!(slug: params[:slug])
    @related_products = @product.related_products
      .includes(:seller, :product_variants, :personalization_options, category: :parent)
      .with_attached_main_image
      .load
    # `.load` porque o parcial pergunta `reviews.any?` antes de iterar; sem
    # isso, a pergunta é um SELECT ... LIMIT 1 a mais.
    @reviews = @product.approved_reviews.includes(:customer).load
    @existing_review = customer_authenticated? ? @product.reviews.find_by(customer: Current.customer) : nil
  end

  def legacy_show
    matches = Product.publicly_visible.where(slug: params[:slug]).limit(2).to_a
    raise ActiveRecord::RecordNotFound unless matches.one?

    product = matches.first
    redirect_to product_path(product.seller, product.slug), status: :moved_permanently
  end

  private

  # A categoria do filtro sai da árvore já carregada: buscá-la por slug no
  # banco seria uma query a mais para um registro que já está em memória.
  def find_category!(slug)
    @categories.find { |category| category.slug == slug } || raise(ActiveRecord::RecordNotFound)
  end
end
