module SellerPortal
  class TermsController < ApplicationController
    layout "application"
    allow_unauthenticated_access only: :show
    before_action :resume_session, only: :show
    before_action :require_seller!, only: :accept

    # O texto mostrado é o mesmo que `SellerTermsAcceptance.record!` grava no
    # aceite: o do tipo de quem está logado (ADR 007). Sem login, os do
    # ateliê, que é quem chega aqui pelo cadastro. Antes, o distribuidor via o
    # texto do ateliê e o aceite gravava o do distribuidor (achado do QA,
    # 2026-11-07).
    def show
      kind = Current.user&.seller&.kind || "atelier"
      @terms_kind = kind
      @terms_version = SellerTerms.version(kind)
      @terms_text = SellerTerms.text(kind)
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
