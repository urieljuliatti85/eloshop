class ProductsController < StorefrontController
  PER_PAGE = 12

  allow_unauthenticated_customer_access

  def index
    scope = Product.active.order(created_at: :desc)
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

    @page = [ params[:page].to_i, 1 ].max
    @total_pages = (scope.count / PER_PAGE.to_f).ceil
    @products = scope.includes(:product_variants).limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def show
    @product = Product.active.includes(:product_variants).find_by!(slug: params[:slug])
    @related_products = @product.related_products.includes(:product_variants)
    @reviews = @product.approved_reviews.includes(:customer)
    @existing_review = customer_authenticated? ? @product.reviews.find_by(customer: Current.customer) : nil
  end
end
