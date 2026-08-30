class ProductsController < StorefrontController
  PER_PAGE = 12

  allow_unauthenticated_customer_access

  def index
    scope = Product.active.order(created_at: :desc)

    @page = [ params[:page].to_i, 1 ].max
    @total_pages = (scope.count / PER_PAGE.to_f).ceil
    @products = scope.includes(:product_variants).limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def show
    @product = Product.active.includes(:product_variants).find_by!(slug: params[:slug])
    @related_products = @product.related_products.includes(:product_variants)
  end
end
