# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Storefront home", type: :request do
  before do
    clear_product_data!
  end

  describe "GET /" do
    it "renders the storefront presentation without the catalog listing" do
      product = Product.create!(name: "Vaso da home", sku: "HOME-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Peças com história, feitas à mão")
      expect(response.body).to include(products_path)
      expect(response.body).not_to include(product.name)
    end

    it "lists the top-level categories, linking each one to the filtered catalog" do
      parent = Category.create!(name: "Casa da home")
      child = Category.create!(name: "Cozinha da home", parent: parent)

      get root_path

      expect(response.body).to include("Explore por categoria")
      expect(response.body).to include(parent.name)
      expect(response.body).to include(CGI.escapeHTML(products_path(category: parent.slug)))
      expect(response.body).not_to include(CGI.escapeHTML(products_path(category: child.slug)))
    end

    it "omits the category section when there is no category yet" do
      Category.delete_all

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Explore por categoria")
    end

    it "sets the default title, description and its own canonical URL" do
      get root_path

      expect(response.body).to include("<title>#{SeoHelper::DEFAULT_TITLE}</title>")
      expect(response.body).to include(%(<meta name="description" content="#{SeoHelper::DEFAULT_DESCRIPTION}">))
      expect(response.body).to include(%(<link rel="canonical" href="http://www.example.com/">))
    end
  end
end
