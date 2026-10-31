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

  # Nome digitado pelo vendedor pode trazer espaços duplos ou nas pontas; no
  # <title> e nos resumos de busca isso aparece como buraco no texto.
  def product_page_title(product)
    "#{product.name.to_s.squish} | EloShop"
  end

  # Usa a descrição escrita pelo vendedor (sem quebras de linha, que o Google
  # mostraria como espaços soltos). Sem ela, monta um resumo com o que é
  # sempre verdade: nome, ateliê e preço.
  def product_meta_description(product)
    text = product.description.to_s.squish.presence ||
      "#{product.name.to_s.squish}, peça artesanal feita à mão pelo ateliê #{product.seller.name}. " \
      "#{format_price(product.starting_price_cents)} na EloShop."

    truncate(text, length: 160)
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
    breadcrumb_structured_data(product.name, product_url(product.seller, product.slug))
  end

  # Mesmo rastro para a página do ateliê (app/views/sellers/show.html.erb).
  def seller_breadcrumb_structured_data(seller)
    breadcrumb_structured_data(seller.name, seller_url(seller.slug))
  end

  # Rastro da categoria na loja: Início → Loja → ancestrais → categoria. Cada
  # nível aponta para a listagem filtrada que o sitemap já publica.
  def category_breadcrumb_structured_data(category, tree)
    path = [ category ]
    while (parent = tree.parent(path.first))
      path.unshift(parent)
    end

    trail = path.map { |c| [ c.name, products_url(category: c.slug) ] }
    breadcrumb_structured_data(trail)
  end

  # JSON-LD da vitrine (schema.org/ItemList) com as peças da página atual.
  def catalog_item_list_structured_data(products)
    data = {
      "@context" => "https://schema.org/",
      "@type" => "ItemList",
      "itemListElement" => products.each_with_index.map do |product, index|
        { "@type" => "ListItem", "position" => index + 1, "url" => product_url(product.seller, product.slug) }
      end
    }

    json_escape(data.to_json).html_safe
  end

  private

  def breadcrumb_structured_data(leaf_name_or_trail, leaf_url = nil)
    trail = leaf_name_or_trail.is_a?(Array) ? leaf_name_or_trail : [ [ leaf_name_or_trail, leaf_url ] ]
    items = [ [ "Início", root_url ], [ "Loja", products_url ] ] + trail

    data = {
      "@context" => "https://schema.org/",
      "@type" => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map do |(name, url), index|
        { "@type" => "ListItem", "position" => index + 1, "name" => name, "item" => url }
      end
    }

    json_escape(data.to_json).html_safe
  end
end
