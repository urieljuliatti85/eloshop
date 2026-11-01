module SellerPortal
  class BaseController < ApplicationController
    layout "seller"

    before_action :require_seller!
    before_action :set_paper_trail_whodunnit
    before_action :require_current_terms!

    helper_method :current_seller

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
      set_mercado_pago_oauth_state
    end

    # Estado do OAuth do Melhor Envio (ADR 005) para o banner de frete real,
    # exibido no ateliê — mesmo padrão do banner do Mercado Pago acima.
    def set_melhor_envio_oauth_state
      oauth = Marketplace::MelhorEnvioOauth.new
      @melhor_envio_oauth_configured = oauth.configured?
      @melhor_envio_oauth_sandbox = oauth.sandbox?
    end

    # O painel tem porta própria: quem não está autenticado vai para o login
    # do ateliê, não para o da administração da plataforma.
    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to seller_login_path
    end

    def require_seller!
      redirect_to seller_login_path unless Current.user&.seller?
    end

    def require_current_terms!
      return if SellerTermsAcceptance.current_for?(Current.user)

      session[:return_to_after_terms] = request.fullpath
      redirect_to seller_terms_path
    end
  end
end
