module SellerPortal
  class BaseController < ApplicationController
    layout "seller"

    before_action :require_seller!

    helper_method :current_seller

    private

    def current_seller
      Current.user.seller
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
  end
end
