module DistributorPortal
  # Painel do distribuidor de insumos (ADR 007, Fase 25), em /atacado/painel.
  # Mesmas regras do painel do ateliê (`SellerPortal::BaseController`): porta
  # de login própria, termos do próprio tipo aceitos e escopo derivado da
  # sessão — `current_seller` é `Current.user.seller` e nada mais, nenhuma
  # ação aceita `seller_id` vindo da URL.
  class BaseController < ApplicationController
    layout "distributor"

    before_action :require_distributor!
    before_action :set_paper_trail_whodunnit
    before_action :require_current_terms!

    helper_method :current_seller

    private

    def current_seller
      Current.user.seller
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to distributor_login_path
    end

    # Ateliê logado vai para o painel dele; admin, para esta porta de login.
    def require_distributor!
      return redirect_to distributor_login_path unless Current.user&.seller?

      redirect_to seller_root_path unless Current.user.portal == :distributor
    end

    def require_current_terms!
      return if SellerTermsAcceptance.current_for?(Current.user)

      session[:return_to_after_terms] = request.fullpath
      redirect_to distributor_terms_path
    end
  end
end
