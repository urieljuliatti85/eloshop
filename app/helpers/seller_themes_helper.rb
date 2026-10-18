module SellerThemesHelper
  # Variáveis CSS do tema do ateliê, para o `style` do contêiner da vitrine.
  def seller_theme_style(seller)
    SellerTheme.css_variables(palette: seller.theme_palette, font: seller.theme_font)
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
end
