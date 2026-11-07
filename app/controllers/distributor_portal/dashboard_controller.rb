module DistributorPortal
  # Visão geral do distribuidor: os Primeiros passos (as mesmas etapas e telas
  # do ateliê, com as do distribuidor: endereço, Mercado Pago, chave PIX e
  # aprovação) enquanto falta alguma, e o resumo do cadastro. O catálogo de
  # insumos chega no PR B da Fase 26.
  class DashboardController < BaseController
    def index
      set_getting_started_block(params[:etapa])
    end
  end
end
