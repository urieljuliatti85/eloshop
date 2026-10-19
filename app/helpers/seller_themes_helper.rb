module SellerThemesHelper
  # Variáveis CSS do tema do ateliê, para o `style` do contêiner da vitrine.
  def seller_theme_style(seller)
    SellerTheme.css_variables(palette: seller.theme_palette, font: seller.theme_font, accent_color: seller.theme_accent_color)
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

  # Cantos e moldura dos cards de peça, aplicados de fora (o parcial do card
  # é compartilhado com o resto da loja e não conhece o tema).
  def seller_cards_class(corners, card_style)
    radius = { "retos" => "[&_article_.aspect-square]:rounded-none", "arredondados" => "[&_article_.aspect-square]:rounded-[2rem]" }[corners]
    frame = {
      "borda" => "[&_article]:rounded-2xl [&_article]:border [&_article]:border-sand-200 [&_article]:p-3",
      "sombra" => "[&_article]:rounded-2xl [&_article]:p-3 [&_article]:shadow-[0_8px_30px_rgba(0,0,0,0.08)]",
      "fundo" => "[&_article]:rounded-2xl [&_article]:p-3 [&_article]:bg-[color-mix(in_srgb,var(--atelier-soft)_45%,white)]"
    }[card_style]
    [ radius, frame ].compact.join(" ")
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
