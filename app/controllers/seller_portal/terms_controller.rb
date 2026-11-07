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
    # 2026-11-07). O visitante de /atacado/termos-comerciais (a rota fixa
    # `kind: "distributor"`) lê os do distribuidor, que é o que o cadastro de
    # lá vai gravar.
    def show
      kind = Current.user&.seller&.kind || terms_kind_from_route
      @terms_kind = kind
      @terms_version = SellerTerms.version(kind)
      @terms_text = SellerTerms.text(kind)
    end

    def accept
      unless params[:terms_accepted] == "1"
        redirect_to terms_path_for(Current.user.seller), alert: "É necessário aceitar os termos comerciais."
        return
      end

      seller = Current.user.seller
      SellerTermsAcceptance.record!(user: Current.user, seller: seller, request: request)
      redirect_to session.delete(:return_to_after_terms).presence || seller_panel_path_for(seller), notice: "Termos comerciais aceitos."
    end

    private

    def terms_kind_from_route
      params[:kind].presence_in(Seller.kinds.keys) || "atelier"
    end

    def terms_path_for(seller)
      seller.distributor? ? distributor_terms_path : seller_terms_path
    end
    helper_method :terms_path_for

    def require_seller!
      return if Current.user&.seller?

      redirect_to terms_kind_from_route == "distributor" ? distributor_login_path : seller_login_path
    end
  end
end
