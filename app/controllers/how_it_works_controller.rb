class HowItWorksController < StorefrontController
  allow_unauthenticated_customer_access

  TABS = %w[compra vende].freeze
  # "Quem vende" tem dois grupos: o ateliê e o armarinho (o distribuidor de
  # insumos do ADR 007). O grupo vem de `?grupo=`, pela mesma razão da aba;
  # `?grupo=distribuidor`, o nome antigo, continua abrindo o armarinho.
  SELLER_GROUPS = %w[atelie armarinho].freeze
  GROUP_ALIASES = { "distribuidor" => "armarinho" }.freeze

  # A aba vem de `?aba=` já no servidor: a página chega com a aba certa
  # aberta, sem depender do Stimulus (que só alterna depois do clique).
  def show
    @tab = TABS.include?(params[:aba]) ? params[:aba] : TABS.first
    group = GROUP_ALIASES.fetch(params[:grupo], params[:grupo])
    @seller_group = SELLER_GROUPS.include?(group) ? group : SELLER_GROUPS.first
  end
end
