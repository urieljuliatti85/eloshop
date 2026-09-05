class SitemapsController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    @products = Product.publicly_visible.includes(:seller).order(:slug)
    @categories = Category::Tree.load(order: :slug).visible
    # Só ateliês com peça publicada: uma vitrine vazia não é conteúdo que
    # valha indexar.
    @sellers = Seller.approved.where(id: Product.publicly_visible.select(:seller_id)).order(:slug)

    render layout: false
  end
end
