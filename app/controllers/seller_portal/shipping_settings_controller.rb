module SellerPortal
  # Frete e entregas: o passo a passo para conectar a SuperFrete, o cartão de
  # conexão (o mesmo de Dados do Ateliê) e a escolha de qual frete o cliente
  # paga. Só leitura do `current_seller`; as ações continuam em
  # SuperfreteConnectionsController e ShippingPreferencesController.
  class ShippingSettingsController < BaseController
    def show
      set_superfrete_oauth_state
    end
  end
end
