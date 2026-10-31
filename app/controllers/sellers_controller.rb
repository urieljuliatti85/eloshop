class SellersController < StorefrontController
  allow_unauthenticated_customer_access

  # A vitrine pública só existe para ateliê aprovado ou liberado na vitrine
  # do pré-cadastro: `Seller.publicly_listed` é a mesma condição que
  # `Product.publicly_visible` exige, então um ateliê pendente fora da vitrine
  # ou suspenso não aparece na listagem (ver `show` para a página dedicada de
  # um ateliê suspenso). Só ateliês com peça publicada: uma
  # vitrine vazia na listagem é um beco, o mesmo critério do filtro do
  # catálogo e do sitemap.
  def index
    @sellers = Seller.publicly_listed
      .where(id: Product.publicly_visible.select(:seller_id))
      .order(:name)

    # Duas leituras fixas para a grade inteira, não uma por ateliê: a contagem
    # de peças e a capa (foto da mais recente de cada um). Mesmo princípio do
    # DISTINCT ON da home.
    @product_counts = Product.publicly_visible.group(:seller_id).count
    @covers = cover_by_seller
  end

  # `pending` fora da vitrine continua 404 puro e simples: esse ateliê nunca
  # teve vitrine pública, então não há nada a diferenciar de uma URL
  # inexistente. Pendente liberado na vitrine (ou aprovado que desconectou o
  # Mercado Pago) tem página normal, só não vende. Um
  # ateliê `suspended`, ao contrário, já existiu publicamente — a página
  # dedicada evita que o link vire ambíguo entre "nunca existiu" e "foi
  # retirado pela plataforma". `hidden_at` é o mesmo raciocínio para uma
  # pausa reversível decidida pelo admin, sem ligação com moderação: mensagem
  # própria, para não sugerir penalidade onde não há uma.
  def show
    @seller = Seller.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound if @seller.pending? && !@seller.showcased?

    if @seller.suspended?
      render :suspended, status: :not_found
      return
    end

    if @seller.hidden?
      render :hidden, status: :not_found
      return
    end

    @products = @seller.storefront_products
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
