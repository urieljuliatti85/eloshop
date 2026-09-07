require "swagger_helper"

RSpec.describe "api/v1/categories", type: :request do
  CATEGORY_SCHEMA = {
    type: :object,
    properties: {
      name: { type: :string },
      slug: { type: :string },
      breadcrumb_name: { type: :string },
      parent_slug: { type: :string, nullable: true },
      product_count: { type: :integer }
    },
    required: %w[name slug breadcrumb_name product_count]
  }.freeze

  CATEGORY_LIST_SCHEMA = {
    type: :object,
    properties: {
      categories: { type: :array, items: CATEGORY_SCHEMA }
    },
    required: %w[categories]
  }.freeze

  path "/api/v1/categories" do
    get "Lista categorias visíveis" do
      tags "Categories"
      produces "application/json"

      response "200", "categorias encontradas" do
        schema CATEGORY_LIST_SCHEMA

        let!(:parent) { Category.create!(name: "Casa rswag") }
        let!(:child) { Category.create!(name: "Decoração rswag", parent: parent) }
        let!(:product) { Product.create!(seller: approved_seller, category: child, name: "Vaso categoria spec", sku: "RSWAG-CAT-001", price_cents: 8990, stock_quantity: 3, status: :active) }

        run_test! do |response|
          body = JSON.parse(response.body)
          child_json = body["categories"].find { |c| c["slug"] == child.slug }

          expect(child_json["breadcrumb_name"]).to eq("Casa rswag > Decoração rswag")
          expect(child_json["parent_slug"]).to eq(parent.slug)
          expect(child_json["product_count"]).to eq(1)
        end
      end

      # Descrição/schema repetidos de propósito: o rswag só mantém um objeto
      # de resposta por status code no swagger.yaml gerado.
      response "200", "categorias encontradas" do
        schema CATEGORY_LIST_SCHEMA

        # Desabilitar o pai esconde a subárvore inteira, igual à loja.
        let!(:inactive_parent) { Category.create!(name: "Oculta rswag", active: false) }
        let!(:hidden_child) { Category.create!(name: "Filha oculta rswag", parent: inactive_parent) }

        run_test! do |response|
          body = JSON.parse(response.body)
          slugs = body["categories"].map { |c| c["slug"] }

          expect(slugs).not_to include(inactive_parent.slug)
          expect(slugs).not_to include(hidden_child.slug)
        end
      end
    end
  end
end
