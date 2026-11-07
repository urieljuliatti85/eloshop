module DistributorPortal
  # O que faz um controller servir ao painel do distribuidor (ADR 007): o
  # layout dele, a porta de login dele e só o tipo distribuidor. Incluído na
  # base do painel e em cada tela que o painel do ateliê já tinha e que o
  # distribuidor reaproveita por subclasse (revisão de arquitetura de
  # 2026-11-07, opção B), para a regra de acesso ser uma só. O escopo continua
  # vindo de `current_seller` (`Current.user.seller`), nunca da URL.
  module Portal
    extend ActiveSupport::Concern

    included do
      layout "distributor"
      self.seller_portals = %i[distributor]
    end

    private

    # Sem sessão: a porta do distribuidor, não a do ateliê.
    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to distributor_login_path
    end

    # Admin vai para a porta do distribuidor; ateliê logado, para o painel
    # dele (`seller_panel_path_for`).
    def require_seller!
      return redirect_to distributor_login_path unless Current.user&.seller?

      redirect_to seller_panel_path_for(current_seller) unless seller_portals.include?(Current.user.portal)
    end
  end
end
