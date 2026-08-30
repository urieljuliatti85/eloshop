require "swagger_helper"

RSpec.describe "api/v1/products", type: :request do
  PRODUCT_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      name: { type: :string },
      slug: { type: :string },
      description: { type: :string, nullable: true },
      price_cents: { type: :integer },
      currency: { type: :string },
      availability_type: { type: :string },
      production_time_range: { type: :string, nullable: true },
      available_for_purchase: { type: :boolean }
    },
    required: %w[id name slug price_cents currency availability_type available_for_purchase]
  }.freeze

  path "/api/v1/products" do
    get "Lista produtos ativos" do
      tags "Products"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false,
                description: "Página da listagem (padrão 1)"

      response "200", "produtos ativos encontrados" do
        schema type: :object,
               properties: {
                 products: { type: :array, items: PRODUCT_SCHEMA },
                 page: { type: :integer },
                 total_pages: { type: :integer }
               },
               required: %w[products page total_pages]

        let!(:active_product) { Product.create!(name: "Vaso rswag spec", sku: "RSWAG-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }
        let!(:draft_product) { Product.create!(name: "Caneca rswag spec", sku: "RSWAG-CANECA-001", price_cents: 4990, stock_quantity: 5, status: :draft) }

        run_test! do |response|
          body = JSON.parse(response.body)
          slugs = body["products"].map { |p| p["slug"] }

          expect(slugs).to include(active_product.slug)
          expect(slugs).not_to include(draft_product.slug)
        end
      end
    end
  end

  path "/api/v1/products/{slug}" do
    get "Exibe um produto ativo pelo slug" do
      tags "Products"
      produces "application/json"
      parameter name: :slug, in: :path, type: :string

      response "200", "produto encontrado" do
        schema PRODUCT_SCHEMA

        let(:product) { Product.create!(name: "Vaso rswag spec", sku: "RSWAG-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }
        let(:slug) { product.slug }

        run_test!
      end

      response "404", "produto inexistente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:slug) { "produto-que-nao-existe" }

        run_test!
      end

      response "404", "produto em rascunho não é exposto pela API pública" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:draft_product) { Product.create!(name: "Caneca rswag spec", sku: "RSWAG-CANECA-001", price_cents: 4990, stock_quantity: 5, status: :draft) }
        let(:slug) { draft_product.slug }

        run_test!
      end
    end
  end
end
