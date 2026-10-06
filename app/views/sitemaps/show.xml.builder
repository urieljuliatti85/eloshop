xml.instruct! :xml, version: "1.0"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url do
    xml.loc root_url
    xml.lastmod @catalog_lastmod.iso8601 if @catalog_lastmod
    xml.changefreq "daily"
  end

  xml.url do
    xml.loc products_url
    xml.lastmod @catalog_lastmod.iso8601 if @catalog_lastmod
    xml.changefreq "daily"
  end

  xml.url do
    xml.loc how_it_works_url
    xml.lastmod SitemapsController::STATIC_PAGES_LASTMOD.fetch(:how_it_works).iso8601
    xml.changefreq "monthly"
  end

  xml.url do
    xml.loc new_seller_registration_url
    xml.lastmod SitemapsController::STATIC_PAGES_LASTMOD.fetch(:new_seller_registration).iso8601
    xml.changefreq "monthly"
  end

  xml.url do
    xml.loc privacy_policy_url
    xml.lastmod SitemapsController::STATIC_PAGES_LASTMOD.fetch(:privacy_policy).iso8601
    xml.changefreq "yearly"
  end

  @categories.each do |category|
    xml.url do
      xml.loc products_url(category: category.slug)
      xml.lastmod @category_lastmod.fetch(category).iso8601
      xml.changefreq "weekly"
    end
  end

  @sellers.each do |seller|
    xml.url do
      xml.loc seller_url(seller.slug)
      xml.lastmod @seller_lastmod.fetch(seller).iso8601
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
