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
      "sombra" => "[&_article]:rounded-2xl [&_article]:p-3 [&_article]:shadow-[0_8px_30px_rgba(0,0,0,0.08)]"
    }[card_style]
    [ radius, frame ].compact.join(" ")
  end

  def seller_instagram_url(seller)
    "https://instagram.com/#{seller.instagram_handle}"
  end

  def seller_whatsapp_url(seller)
    "https://wa.me/#{seller.whatsapp_number}"
  end
end
