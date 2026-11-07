module SellerPortal
  class BaseController < ApplicationController
    layout "seller"

    before_action :require_seller!
    before_action :set_paper_trail_whodunnit
    before_action :require_current_terms!

    helper_method :current_seller

    # Os tipos de vendedor que cada controller atende (ADR 007). O painel em
    # /painel é do ateliê; só a conexão do Mercado Pago serve aos dois, porque
    # o redirect URI registrado no provedor aponta para cá.
    class_attribute :seller_portals, default: %i[atelier]

    private

    def current_seller
      Current.user.seller
    end

    # Estado do OAuth do Mercado Pago para o banner de "Recebimentos e
    # verificação" (app/views/seller_portal/mercado_pago_connections/_banner),
    # exibido tanto no dashboard quanto no ateliê.
    def set_mercado_pago_oauth_state
      oauth = Marketplace::MercadoPagoOauth.new
      @mercado_pago_oauth_configured = oauth.configured?
      @mercado_pago_oauth_sandbox = oauth.sandbox?
    end

    # Primeiros passos como o painel inicial os mostra (`dashboard/_setup`),
    # contados por `Seller#setup_steps`. A etapa aberta vem da URL
    # (`?etapa=`); sem ela, a primeira pendente.
    def set_getting_started_block(step_slug = nil)
      @getting_started_steps = current_seller.setup_steps
      @getting_started_current_step = GettingStartedController::STEP_SLUGS.key(step_slug) || @getting_started_steps.key(false)
      @getting_started_current_step = @getting_started_steps.key(false) unless @getting_started_steps.key?(@getting_started_current_step)
      set_mercado_pago_oauth_state
      set_superfrete_oauth_state
    end

    # A conexão com a SuperFrete só aparece quando dá para usá-la: cotações
    # externas ligadas no ambiente e credenciais de plataforma configuradas.
    def set_superfrete_oauth_state
      @superfrete_connection_available = Shipping::Providers.enabled? && Marketplace::SuperfreteOauth.new.configured?
    end

    # O painel tem porta própria: quem não está autenticado vai para o login
    # do ateliê, não para o da administração da plataforma.
    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to seller_login_path
    end

    # Distribuidor logado em /painel vai para o painel dele, não para o login
    # do ateliê: a sessão é válida, só a porta é outra.
    def require_seller!
      return redirect_to seller_login_path unless Current.user&.seller?

      redirect_to seller_panel_path_for(current_seller) unless seller_portals.include?(Current.user.portal)
    end

    def require_current_terms!
      return if SellerTermsAcceptance.current_for?(Current.user)

      session[:return_to_after_terms] = request.fullpath
      redirect_to current_seller.distributor? ? distributor_terms_path : seller_terms_path
    end
  end
end
