class SitemapsController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    @products = Product.publicly_visible.includes(:seller).order(:slug)
    @categories = Category::Tree.load(order: :slug).visible

    render layout: false
  end
end
