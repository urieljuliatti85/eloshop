# Lista pública dos distribuidores de insumos (ADR 007), em /distribuidores.
# Mostra só `Seller.supply_listed` (aprovado, ou pendente liberado pelo admin
# na vitrine do pré-cadastro, nunca escondido ou suspenso), a lista própria
# do distribuidor, que nunca se mistura com a dos ateliês em /artesaos.
class DistributorsController < StorefrontController
  allow_unauthenticated_customer_access

  def index
    @distributors = Seller.supply_listed.order(:name)
  end

  # A loja do distribuidor (/distribuidores/:slug): só quem está na vitrine de
  # insumos; pendente sem liberação, escondido, suspenso ou ateliê respondem
  # 404 (um ateliê tem a página dele em /artesaos).
  def show
    @distributor = Seller.supply_listed.find_by!(slug: params[:slug])
    @supplies = @distributor.products.active.preload(:seller, :price_tiers, main_image_attachment: :blob).order(:name)
  end
end
