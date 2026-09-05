module SellerPortal
  # Dados do próprio ateliê. O escopo vem sempre de `current_seller` — nenhuma
  # ação aceita id de vendedor por parâmetro.
  class AteliersController < BaseController
    before_action :set_oauth_state, only: :show

    def show
    end

    def edit
    end

    def update
      if current_seller.update(atelier_params)
        redirect_to seller_atelier_path, notice: "Dados do ateliê atualizados."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Só o nome: `slug` já está nas URLs públicas dos produtos, e trocá-lo
    # quebraria links compartilhados; `status` é decisão da plataforma.
    def atelier_params
      params.expect(seller: [ :name ])
    end

    def set_oauth_state
      oauth = Marketplace::MercadoPagoOauth.new
      @mercado_pago_oauth_configured = oauth.configured?
      @mercado_pago_oauth_sandbox = oauth.sandbox?
    end
  end
end
