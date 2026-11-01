class HowItWorksController < StorefrontController
  allow_unauthenticated_customer_access

  TABS = %w[compra vende].freeze

  # A aba vem de `?aba=` já no servidor: a página chega com a aba certa
  # aberta, sem depender do Stimulus (que só alterna depois do clique).
  def show
    @tab = TABS.include?(params[:aba]) ? params[:aba] : TABS.first
  end
end
