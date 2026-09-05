xml.instruct! :xml, version: "1.0"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url do
    xml.loc root_url
    xml.changefreq "daily"
  end

  xml.url do
    xml.loc products_url
    xml.changefreq "daily"
  end

  @categories.each do |category|
    xml.url do
      xml.loc products_url(category: category.slug)
      xml.changefreq "weekly"
    end
  end

  @sellers.each do |seller|
    xml.url do
      xml.loc seller_url(seller.slug)
      xml.changefreq "weekly"
    end
  end

  @products.each do |product|
    xml.url do
      xml.loc product_url(product.seller, product.slug)
      xml.lastmod product.updated_at.iso8601
      xml.changefreq "weekly"
    end
  end
end
