module SellerPortal
  # Tema da vitrine pública do próprio ateliê. Como no resto do painel, o
  # escopo vem de `current_seller`; nenhuma ação aceita id de vendedor.
  class ThemesController < BaseController
    def edit
    end

    def update
      if current_seller.update(theme_params)
        purge_removed_images
        redirect_to edit_seller_theme_path, notice: "Tema da vitrine atualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Remover é um checkbox à parte: um campo de arquivo vazio não diz se o
    # vendedor quer manter ou apagar a imagem atual.
    def purge_removed_images
      current_seller.logo.purge_later if params[:remove_logo] == "1"
      current_seller.cover_image.purge_later if params[:remove_cover_image] == "1"
    end

    def theme_params
      params.expect(seller: %i[logo cover_image footer_text theme_palette theme_font theme_layout theme_hero])
    end
  end
end
