module SellerPortal
  # Tema da vitrine pública do próprio ateliê. Como no resto do painel, o
  # escopo vem de `current_seller`; nenhuma ação aceita id de vendedor.
  class ThemesController < BaseController
    THEME_FIELDS = %i[
      footer_text about_text notice_text instagram_handle whatsapp_number
      theme_palette theme_font theme_layout theme_hero theme_corners theme_card_style theme_accent_color
      theme_background theme_ornament theme_image_ratio theme_heading_font
    ].freeze
    THEME_IMAGES = %i[logo cover_image about_image].freeze

    # Os cards da vitrine perguntam se há cliente logado (botão de favoritos).
    # Aqui quem navega é o artesão e a página é inerte: nunca há cliente.
    helper_method :customer_authenticated?

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

    # A vitrine real, com o rascunho do formulário aplicado em memória. Nada é
    # gravado (o registro fica somente leitura) e os anexos são os já salvos.
    def preview
      @seller = current_seller
      @seller.assign_attributes(preview_params)
      @seller.theme_sections |= [ "catalog" ]
      @seller.readonly!
      @products = @seller.storefront_products
      render "sellers/show", layout: "theme_preview"
    end

    private

    def customer_authenticated?
      false
    end

    # Remover é um checkbox à parte: um campo de arquivo vazio não diz se o
    # vendedor quer manter ou apagar a imagem atual.
    def purge_removed_images
      current_seller.logo.purge_later if params[:remove_logo] == "1"
      current_seller.cover_image.purge_later if params[:remove_cover_image] == "1"
      current_seller.about_image.purge_later if params[:remove_about_image] == "1"
    end

    def theme_params
      with_custom_color(params.expect(seller: [ *THEME_IMAGES, *THEME_FIELDS, theme_sections: [] ]))
    end

    # Sem `seller` na query a pré-visualização mostra o que está salvo.
    def preview_params
      with_custom_color(params.fetch(:seller, {}).permit(*THEME_FIELDS, theme_sections: []))
    end

    # A cor própria só vale com o checkbox ligado: um input de cor nunca vem
    # vazio, então sem ele não há como voltar à paleta.
    def with_custom_color(permitted)
      permitted[:theme_accent_color] = nil unless params[:use_custom_color] == "1"
      permitted
    end
  end
end
