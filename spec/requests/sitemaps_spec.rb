# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sitemap", type: :request do
  before do
    clear_product_data!
  end

  describe "GET /sitemap.xml" do
    it "lists active products but not draft or discontinued ones" do
      active = Product.create!(seller: approved_seller, name: "Vaso sitemap", sku: "SITE-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      draft = Product.create!(seller: approved_seller, name: "Caneca rascunho sitemap", sku: "SITE-002", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :draft)
      discontinued = Product.create!(seller: approved_seller, name: "Item descontinuado sitemap", sku: "SITE-003", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :discontinued)

      get sitemap_path(format: :xml)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include(product_url(active.seller, active.slug))
      expect(response.body).not_to include(product_url(draft.seller, draft.slug))
      expect(response.body).not_to include(product_url(discontinued.seller, discontinued.slug))
    end

    it "includes the homepage and catalog URLs" do
      get sitemap_path(format: :xml)

      expect(response.body).to include(root_url)
      expect(response.body).to include(products_url)
    end
  end

  describe "GET /sitemap.xml pages and lastmod" do
    def sitemap_entries
      get sitemap_path(format: :xml)
      Nokogiri::XML(response.body).remove_namespaces!.xpath("//url").to_h do |url|
        [ url.at_xpath("loc").text, url.at_xpath("lastmod")&.text ]
      end
    end

    it "lists the public static pages" do
      entries = sitemap_entries

      expect(entries.keys).to include(how_it_works_url, new_seller_registration_url, privacy_policy_url)
    end

    it "gives every URL a lastmod" do
      Product.create!(seller: approved_seller, name: "Vaso lastmod", sku: "SITE-LM1", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      entries = sitemap_entries

      expect(entries).not_to be_empty
      expect(entries.select { |_loc, lastmod| lastmod.blank? }).to be_empty
    end

    it "dates the storefront pages by the most recently changed product they show" do
      older = Product.create!(seller: approved_seller, name: "Vaso antigo", sku: "SITE-LM2", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      newer = Product.create!(seller: approved_seller, name: "Vaso novo", sku: "SITE-LM3", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      older.update_columns(updated_at: Time.utc(2026, 1, 1, 12))
      newer.update_columns(updated_at: Time.utc(2026, 3, 1, 12))

      entries = sitemap_entries

      # O fuso do app é o de Brasília, então comparamos o instante, não o texto.
      expect(Time.iso8601(entries[root_url])).to eq(Time.utc(2026, 3, 1, 12))
      expect(Time.iso8601(entries[products_url])).to eq(Time.utc(2026, 3, 1, 12))
      expect(Time.iso8601(entries[seller_url(approved_seller.slug)])).to eq(Time.utc(2026, 3, 1, 12))
      expect(Time.iso8601(entries[product_url(older.seller, older.slug)])).to eq(Time.utc(2026, 1, 1, 12))
    end
  end

  describe "GET /sitemap.xml categories" do
    def sitemap_locs
      get sitemap_path(format: :xml)
      Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    end

    def category_product(category, sku)
      Product.create!(seller: approved_seller, category: category, name: "Peça #{sku}", sku: sku, price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
    end

    it "omits a category with no public product, so crawlers do not hit an empty page" do
      empty = Category.create!(name: "Categoria vazia sitemap", slug: "categoria-vazia-sitemap")
      filled = Category.create!(name: "Categoria cheia sitemap", slug: "categoria-cheia-sitemap")
      category_product(filled, "SITE-C1")

      locs = sitemap_locs

      expect(locs).to include(products_url(category: filled.slug))
      expect(locs).not_to include(products_url(category: empty.slug))
    end

    it "keeps a parent category whose only products are in a subcategory" do
      parent = Category.create!(name: "Pai sitemap", slug: "pai-sitemap")
      child = Category.create!(name: "Filha sitemap", slug: "filha-sitemap", parent: parent)
      category_product(child, "SITE-C2")

      locs = sitemap_locs

      expect(locs).to include(products_url(category: parent.slug), products_url(category: child.slug))
    end

    it "omits a category whose only product is a draft" do
      category = Category.create!(name: "Só rascunho sitemap", slug: "so-rascunho-sitemap")
      category_product(category, "SITE-C3").update!(status: :draft)

      expect(sitemap_locs).not_to include(products_url(category: category.slug))
    end
  end

  # Crawlers exigem URL absoluta na linha Sitemap do robots.txt; o caminho
  # relativo é ignorado.
  describe "public/robots.txt" do
    it "points to the sitemap with its full URL" do
      sitemap_lines = Rails.public_path.join("robots.txt").read.lines.grep(/\ASitemap:/i)

      expect(sitemap_lines.map(&:strip)).to eq([ "Sitemap: https://eloshop.shop/sitemap.xml" ])
    end
  end

  # O Google exige que este arquivo continue no ar para manter a propriedade
  # verificada no Search Console; apagá-lo derruba a verificação.
  describe "Google Search Console verification file" do
    it "stays in public/ with the content Google expects" do
      file = Rails.public_path.join("googlec5fa6aba7c229f86.html")

      expect(file.read.strip).to eq("google-site-verification: googlec5fa6aba7c229f86.html")
    end
  end
end
