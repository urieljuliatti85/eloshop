module SellerThemesHelper
  # Variáveis CSS do tema do ateliê, para o `style` do contêiner da vitrine.
  def seller_theme_style(seller)
    SellerTheme.css_variables(palette: seller.theme_palette, font: seller.theme_font, accent_color: seller.theme_accent_color,
                              heading_font: seller.theme_heading_font, background: seller.theme_background)
  end

  # No fundo escuro, `atelier-dark` troca as cores do texto (application.css).
  def seller_theme_class(seller)
    "atelier-dark" if SellerTheme.dark?(seller.theme_background)
  end

  # Classes da grade do catálogo (literais completas, para o Tailwind achar).
  def seller_catalog_grid_class(layout)
    case layout
    when "ampla" then "mt-8 grid grid-cols-2 gap-x-6 gap-y-12 lg:grid-cols-3"
    else "mt-8 grid grid-cols-2 gap-x-5 gap-y-10 lg:grid-cols-4"
    end
  end

  # No layout "destaque" a peça mais recente ocupa um bloco 2x2.
  def seller_catalog_item_class(layout, index)
    "col-span-2 row-span-2" if layout == "destaque" && index.zero?
  end

  # Cantos do topo. Literais completas, para o Tailwind achar.
  def seller_hero_radius_class(corners)
    { "retos" => "rounded-none", "arredondados" => "rounded-[3rem]" }.fetch(corners, "rounded-[2rem]")
  end

  # Cantos, moldura e proporção da foto dos cards de peça, aplicados de fora
  # (o parcial do card é compartilhado com o resto da loja e não conhece o
  # tema). A proporção sobrescreve o `aspect-square` do próprio card.
  def seller_cards_class(seller)
    radius = { "retos" => "[&_article_.aspect-square]:rounded-none", "arredondados" => "[&_article_.aspect-square]:rounded-[2rem]" }[seller.theme_corners]
    ratio = { "retrato" => "[&_article_.aspect-square]:aspect-[4/5]", "paisagem" => "[&_article_.aspect-square]:aspect-[4/3]" }[seller.theme_image_ratio]
    frame = {
      "borda" => "[&_article]:rounded-2xl [&_article]:border [&_article]:border-sand-200 [&_article]:p-3",
      "sombra" => "[&_article]:rounded-2xl [&_article]:p-3 [&_article]:shadow-[0_8px_30px_rgba(0,0,0,0.08)]",
      "fundo" => "[&_article]:rounded-2xl [&_article]:p-3 [&_article]:bg-[var(--atelier-card)]"
    }[seller.theme_card_style]
    [ radius, ratio, frame ].compact.join(" ")
  end

  # Foto do topo: a capa enviada pelo ateliê ou, sem ela, a da peça mais
  # recente. É uma variante, não o original: o topo é o elemento mais pesado
  # da página e o original da peça pode ter vários MB.
  def seller_cover_photo(seller, products)
    image = seller.cover_image.attached? ? seller.cover_image : products.find { |product| product.main_image.attached? }&.main_image
    image&.variant(resize_to_limit: [ 1600, 700 ])
  end

  # Seções que de fato têm o que mostrar: "Sobre" e rodapé vazios não entram,
  # para não sobrar um divisor solto entre duas seções.
  def seller_visible_sections(seller)
    seller.theme_sections.select do |section|
      case section
      when "about" then seller.about_text.present? || seller.about_image.attached?
      when "footer" then seller.footer_text.present?
      else true
      end
    end
  end

  # Faixa de ornamento na cor da paleta, ou nil sem ornamento.
  def seller_ornament(seller)
    style = SellerTheme.ornament_style(seller.theme_ornament)
    tag.div(class: "w-full bg-[var(--atelier-accent-on-page)] opacity-60", style: style, aria: { hidden: true }) if style
  end

  # Divisor entre seções: o ornamento do tema ou, sem ele, uma linha.
  def seller_section_divider(seller)
    seller_ornament(seller) || tag.hr(class: "border-sand-200")
  end

  def seller_instagram_url(seller)
    "https://instagram.com/#{seller.instagram_handle}"
  end

  def seller_whatsapp_url(seller)
    "https://wa.me/#{seller.whatsapp_number}"
  end

  THEME_CHOICE_CLASS = "group flex cursor-pointer flex-col items-stretch gap-2 rounded-2xl border border-stone-200 bg-white p-2.5 " \
                       "transition hover:border-stone-400 has-[:checked]:border-stone-900 has-[:checked]:ring-2 " \
                       "has-[:checked]:ring-stone-900 has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-brand-400".freeze

  # Cartão de escolha do editor de tema: um rádio escondido, uma miniatura
  # (o bloco) e o rótulo. A seleção aparece pelo `:checked` do próprio rádio.
  def theme_choice(form, attribute, value, label, &visual)
    tag.label(class: THEME_CHOICE_CLASS) do
      safe_join([
        form.radio_button(attribute, value, class: "sr-only"),
        tag.span(capture(&visual), class: "flex h-14 items-center justify-center overflow-hidden rounded-xl bg-stone-50"),
        tag.span(label, class: "text-center text-xs font-semibold leading-tight text-stone-700")
      ])
    end
  end
end
