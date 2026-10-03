module SellerPortal
  # Passo a passo estático para criar a Conta Vendedor no Mercado Pago. Sem
  # modelo nem escopo por vendedor: o conteúdo é o mesmo para todos, e só o
  # estado da conexão (`current_seller`) muda o que a página oferece.
  class MercadoPagoGuidesController < BaseController
    def show
      set_mercado_pago_oauth_state
    end
  end
end
