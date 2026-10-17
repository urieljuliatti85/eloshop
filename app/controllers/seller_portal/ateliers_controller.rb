module SellerPortal
  # Dados do próprio ateliê. O escopo vem sempre de `current_seller` — nenhuma
  # ação aceita id de vendedor por parâmetro.
  class AteliersController < BaseController
    before_action :set_mercado_pago_oauth_state, :set_melhor_envio_oauth_state, only: :show

    def show
    end

    def edit
    end

    def update
      if current_seller.update(atelier_params)
        purge_removed_theme_images
        redirect_to seller_atelier_path, notice: "Dados do ateliê atualizados."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Remover é um checkbox à parte: um campo de arquivo vazio não diz se o
    # vendedor quer manter ou apagar a imagem atual.
    def purge_removed_theme_images
      current_seller.logo.purge_later if params[:remove_logo] == "1"
      current_seller.cover_image.purge_later if params[:remove_cover_image] == "1"
    end

    # Nome, dados do proprietário, endereço de origem e tema da vitrine. `slug` já está nas
    # URLs públicas dos produtos, e trocá-lo quebraria links compartilhados;
    # `status` é decisão da plataforma. CPF em branco não apaga o já
    # cadastrado: `Seller#cpf=` só atribui quando o valor vem presente.
    def atelier_params
      params.expect(seller: [ :name, :owner_full_name, :cpf, *Seller::ORIGIN_ADDRESS_FIELDS, :logo, :cover_image, :footer_text ])
    end
  end
end
