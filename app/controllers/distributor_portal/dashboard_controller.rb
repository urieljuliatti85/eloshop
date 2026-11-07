module DistributorPortal
  # Visão geral do distribuidor: estado do cadastro, conexão com o Mercado Pago
  # e dados declarados. O catálogo de insumos chega na Fase 26.
  class DashboardController < BaseController
    def index
      @mercado_pago_oauth_configured = Marketplace::MercadoPagoOauth.new.configured?
    end
  end
end
