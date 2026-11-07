class HowItWorksController < StorefrontController
  allow_unauthenticated_customer_access

  TABS = %w[compra vende].freeze
  # "Quem vende" tem dois grupos: o ateliê e o distribuidor de insumos
  # (ADR 007). O grupo vem de `?grupo=`, pela mesma razão da aba.
  SELLER_GROUPS = %w[atelie distribuidor].freeze

  # A aba vem de `?aba=` já no servidor: a página chega com a aba certa
  # aberta, sem depender do Stimulus (que só alterna depois do clique).
  def show
    @tab = TABS.include?(params[:aba]) ? params[:aba] : TABS.first
    @seller_group = SELLER_GROUPS.include?(params[:grupo]) ? params[:grupo] : SELLER_GROUPS.first
  end
end
