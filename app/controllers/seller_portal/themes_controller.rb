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
      current_seller.about_image.purge_later if params[:remove_about_image] == "1"
    end

    # A cor própria só vale com o checkbox ligado: um input de cor nunca vem
    # vazio, então sem ele não há como voltar à paleta.
    def theme_params
      permitted = params.expect(seller: [ :logo, :cover_image, :about_image, :footer_text, :about_text, :notice_text,
                                          :instagram_handle, :whatsapp_number, :theme_palette, :theme_font,
                                          :theme_layout, :theme_hero, :theme_corners, :theme_card_style,
                                          :theme_accent_color, theme_sections: [] ])
      permitted[:theme_accent_color] = nil unless params[:use_custom_color] == "1"
      permitted
    end
  end
end
