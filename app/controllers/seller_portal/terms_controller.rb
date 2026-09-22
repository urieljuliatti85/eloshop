module SellerPortal
  class TermsController < ApplicationController
    layout "application"
    allow_unauthenticated_access only: :show
    before_action :require_seller!, only: :accept

    def show
      @terms_version = SellerTerms.version
      @terms_text = SellerTerms.text
    end

    def accept
      unless params[:terms_accepted] == "1"
        redirect_to seller_terms_path, alert: "É necessário aceitar os termos comerciais."
        return
      end

      SellerTermsAcceptance.record!(user: Current.user, seller: Current.user.seller, request: request)
      redirect_to session.delete(:return_to_after_terms).presence || seller_root_path, notice: "Termos comerciais aceitos."
    end

    private

    def require_seller!
      return if Current.user&.seller?

      redirect_to seller_login_path
    end
  end
end
