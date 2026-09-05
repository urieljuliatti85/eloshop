class SellersController < StorefrontController
  allow_unauthenticated_customer_access

  # A vitrine pública só existe para artesão aprovado: `Seller.approved` é a
  # mesma condição que `Product.publicly_visible` exige, então um ateliê
  # pendente ou suspenso responde 404 em vez de expor uma página vazia.
  # Só ateliês com peça publicada: uma vitrine vazia na listagem é um beco,
  # o mesmo critério do filtro do catálogo e do sitemap.
  def index
    @sellers = Seller.approved
      .where(id: Product.publicly_visible.select(:seller_id))
      .order(:name)

    # Duas leituras fixas para a grade inteira, não uma por ateliê: a contagem
    # de peças e a capa (foto da mais recente de cada um). Mesmo princípio do
    # DISTINCT ON da home.
    @product_counts = Product.publicly_visible.group(:seller_id).count
    @covers = cover_by_seller
  end

  def show
    @seller = Seller.approved.find_by!(slug: params[:slug])
    @products = @seller.products.publicly_visible
      .order(created_at: :desc)
      # preload, e não includes: a capa arrasta as tabelas do Active Storage
      # e o plano estourava o jit_above_cost no catálogo (ver Fase 17).
      .preload(:seller, :product_variants, category: :parent)
      .preload(main_image_attachment: :blob)
      .load
  end

  private

  # DISTINCT ON devolve no máximo uma linha por vendedor: o custo acompanha o
  # número de ateliês, não o tamanho do catálogo.
  def cover_by_seller
    ids = Product.publicly_visible
      .where.associated(:main_image_attachment)
      .select("DISTINCT ON (products.seller_id) products.id, products.seller_id, products.created_at")
      .order("products.seller_id", "products.created_at DESC")
      .map(&:id)

    Product.where(id: ids).with_attached_main_image.index_by(&:seller_id)
  end
end
