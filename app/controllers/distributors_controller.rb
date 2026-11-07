# Lista pública dos distribuidores de insumos (ADR 007), em /distribuidores.
# Mostra só `Seller.supply_listed` (aprovado, ou pendente liberado pelo admin
# na vitrine do pré-cadastro, nunca escondido ou suspenso), a lista própria
# do distribuidor, que nunca se mistura com a dos ateliês em /artesaos.
class DistributorsController < StorefrontController
  allow_unauthenticated_customer_access

  def index
    @distributors = Seller.supply_listed.order(:name)
  end
end
