module SeoHelper
  DEFAULT_TITLE = "EloShop — Artesanato e produtos feitos à mão"
  DEFAULT_DESCRIPTION = "Loja online de artesanato e peças feitas à mão: cerâmica, madeira, tecido e muito mais, direto de quem produz."

  def page_title
    content_for(:title).presence || DEFAULT_TITLE
  end

  def page_description
    content_for(:meta_description).presence || DEFAULT_DESCRIPTION
  end

  def canonical_url
    content_for(:canonical_url).presence || request.original_url
  end

  def og_type
    content_for(:og_type).presence || "website"
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
end
