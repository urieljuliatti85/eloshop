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
end
