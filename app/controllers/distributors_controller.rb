# Lista pública dos distribuidores de insumos (ADR 007), em /armarinhos ("Armarinho" na tela).
# Mostra só `Seller.supply_listed` (aprovado, ou pendente liberado pelo admin
# na vitrine do pré-cadastro, nunca escondido ou suspenso), a lista própria
# do distribuidor, que nunca se mistura com a dos ateliês em /artesaos.
class DistributorsController < StorefrontController
  allow_unauthenticated_customer_access

  def index
    supplies = Product.supply_visible.preload(:seller, :price_tiers, :materials).order(:name)
    @supplies_by_distributor = supplies.group_by(&:seller_id)
    @preview_distributor = Seller.supply_listed.find_by(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG)
    @distributors = Seller.supply_listed.where.not(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG).order(:name)
    @materials = Material.order(:name)
  end

  # A loja do distribuidor (/armarinhos/:slug): só quem está na vitrine de
  # insumos; pendente sem liberação, escondido, suspenso ou ateliê respondem
  # 404 (um ateliê tem a página dele em /artesaos).
  def show
    @distributor = Seller.supply_listed.find_by!(slug: params[:slug])
    @distributor_preview = @distributor.slug == Seller::PREVIEW_DISTRIBUTOR_SLUG
    @supplies = @distributor.products.active.preload(:seller, :price_tiers, :materials, main_image_attachment: :blob).order(:name)
  end
end
