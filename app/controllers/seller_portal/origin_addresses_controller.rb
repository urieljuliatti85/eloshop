module SellerPortal
  # Endereço de origem preenchido na etapa 1 dos Primeiros passos, dentro do
  # painel inicial: o formulário vive no Turbo Frame do bloco, então salvar
  # abre a próxima etapa sem sair do /painel. Só os campos de endereço; o
  # resto dos dados do ateliê continua em AteliersController.
  class OriginAddressesController < BaseController
    def update
      # Antes de atribuir: o bloco reexibido em caso de erro mostra a etapa
      # como estava gravada, não como o formulário inválido a deixaria.
      set_getting_started_block(GettingStartedController::STEP_SLUGS[:address])
      current_seller.assign_attributes(params.expect(seller: [ *Seller::ORIGIN_ADDRESS_FIELDS, :origin_complement ]))

      if current_seller.origin_address_complete? && current_seller.save
        redirect_to panel_path(:root), status: :see_other
      else
        # `valid?` lista os campos que faltam. Tudo em branco passa na
        # validação do `Seller` (o endereço é opcional para o cadastro), mas
        # não fecha a etapa.
        current_seller.errors.add(:base, "Preencha o endereço completo.") if current_seller.valid?
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
