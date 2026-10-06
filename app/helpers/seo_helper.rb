module SeoHelper
  DEFAULT_TITLE = "EloShop — Artesanato e produtos feitos à mão"
  # Cartão de compartilhamento (1200x630, o tamanho que WhatsApp, Instagram e
  # Facebook recomendam) usado quando a página não tem imagem própria.
  DEFAULT_OG_IMAGE = "og-card.jpg"
  DEFAULT_OG_IMAGE_SIZE = [ 1200, 630 ].freeze
  DEFAULT_DESCRIPTION = "Loja online de artesanato e peças feitas à mão: cerâmica, madeira, tecido e muito mais, direto de quem produz."

  def page_title
    content_for(:title).presence || DEFAULT_TITLE
  end

  def page_description
    content_for(:meta_description).presence || DEFAULT_DESCRIPTION
  end

  def page_og_image
    content_for(:og_image).presence || image_url(DEFAULT_OG_IMAGE)
  end

  # Só declara as dimensões da imagem da página quando o Active Storage já as
  # conhece; sem isso, declarar o tamanho do cartão padrão para outra imagem
  # seria mentir ao rastreador.
  def page_og_image_size
    return DEFAULT_OG_IMAGE_SIZE if content_for(:og_image).blank?

    [ content_for(:og_image_width).presence, content_for(:og_image_height).presence ]
  end

  def canonical_url
    content_for(:canonical_url).presence || request.original_url
  end

  def og_type
    content_for(:og_type).presence || "website"
  end

  # Dimensões do og:image quando o Active Storage já analisou a imagem
  # (metadata de width/height só existe após o AnalyzeJob rodar) — evita
  # declarar um tamanho que não corresponde ao arquivo real. Retorna um
  # array [width, height] em vez de um Hash porque `content_for` grava o
  # valor como string (via to_s), então o chamador precisa de algo simples
  # de repassar por dois content_for separados.
  def og_image_dimensions(attachment)
    return unless attachment&.attached?

    width = attachment.metadata[:width]
    height = attachment.metadata[:height]
    return unless width && height

    [ width, height ]
  end

  # JSON-LD da home: quem é a loja (Organization) e o site (WebSite), para o
  # Google exibir nome e logo da marca nos resultados.
  def site_structured_data
    data = {
      "@context" => "https://schema.org",
      "@graph" => [
        { "@type" => "Organization", "name" => "EloShop", "url" => root_url, "logo" => image_url("logo.png") },
        {
          "@type" => "WebSite", "name" => "EloShop", "url" => root_url,
          # Mesmo parâmetro `q` do formulário do cabeçalho e do filtro do catálogo.
          "potentialAction" => {
            "@type" => "SearchAction",
            "target" => { "@type" => "EntryPoint", "urlTemplate" => "#{products_url}?q={search_term_string}" },
            "query-input" => "required name=search_term_string"
          }
        }
      ]
    }

    json_escape(data.to_json).html_safe
  end

  # JSON-LD do produto (schema.org/Product) — json_escape evita que um
  # valor com "</script>" (ex.: nome ou descrição do produto) escape da
  # tag <script> e quebre o HTML ao redor.
  def product_structured_data(product)
    data = {
      "@context" => "https://schema.org/",
      "@type" => "Product",
      "name" => product.name,
      "description" => product.description.to_s.presence,
      "sku" => product.sku,
      # No marketplace quem assina a peça é o ateliê, não a plataforma — é o
      # que `brand` significa para o schema.org.
      "brand" => { "@type" => "Brand", "name" => product.seller.name },
      "offers" => {
        "@type" => "Offer",
        "url" => product_url(product.seller, product.slug),
        "priceCurrency" => product.currency,
        "price" => product.starting_price_cents / 100.0,
        "availability" => product.available_for_purchase? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock"
      }
    }

    data["image"] = rails_blob_url(product.main_image) if product.main_image.attached?

    if product.reviews_count.positive?
      data["aggregateRating"] = {
        "@type" => "AggregateRating",
        "ratingValue" => product.average_rating,
        "reviewCount" => product.reviews_count
      }
    end

    json_escape(data.compact.to_json).html_safe
  end

  # JSON-LD do rastro de navegação (schema.org/BreadcrumbList) do produto,
  # espelhando o breadcrumb visual em app/views/products/show.html.erb.
  def product_breadcrumb_structured_data(product)
    data = {
      "@context" => "https://schema.org/",
      "@type" => "BreadcrumbList",
      "itemListElement" => [
        { "@type" => "ListItem", "position" => 1, "name" => "Início", "item" => root_url },
        { "@type" => "ListItem", "position" => 2, "name" => "Loja", "item" => products_url },
        { "@type" => "ListItem", "position" => 3, "name" => product.name, "item" => product_url(product.seller, product.slug) }
      ]
    }

    json_escape(data.to_json).html_safe
  end
end
