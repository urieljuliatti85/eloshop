module DistributorPortal
  # "Dados da distribuidora": o par do "Dados do ateliê" (AteliersController),
  # com o que é do distribuidor (CNPJ, declaração de nota fiscal) e sem o que
  # é da vitrine de peças. O escopo é sempre `current_seller`; o slug não muda
  # (já está no endereço da loja), e status, tipo e CPF não se editam aqui.
  class ProfilesController < BaseController
    before_action :set_mercado_pago_oauth_state, only: :show

    def show
    end

    def edit
    end

    def update
      if current_seller.update(profile_params)
        redirect_to distributor_profile_path, notice: "Dados da distribuidora atualizados."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Declaração de nota fiscal: opcional; em branco fica `nil` (ADR 007).
    def profile_params
      permitted = params.expect(seller: [ :name, :owner_full_name, :cnpj, :issues_invoices, *Seller::ORIGIN_ADDRESS_FIELDS, :origin_complement ])
      permitted[:issues_invoices] = permitted[:issues_invoices].presence if permitted.key?(:issues_invoices)
      permitted
    end
  end
end
