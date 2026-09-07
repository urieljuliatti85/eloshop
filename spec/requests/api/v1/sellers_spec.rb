require "swagger_helper"

RSpec.describe "api/v1/sellers", type: :request do
  SELLER_SCHEMA = {
    type: :object,
    properties: {
      name: { type: :string },
      slug: { type: :string },
      product_count: { type: :integer }
    },
    required: %w[name slug product_count]
  }.freeze

  SELLER_LIST_SCHEMA = {
    type: :object,
    properties: {
      sellers: { type: :array, items: SELLER_SCHEMA }
    },
    required: %w[sellers]
  }.freeze

  path "/api/v1/sellers" do
    get "Lista ateliês aprovados com peças publicadas" do
      tags "Sellers"
      produces "application/json"

      response "200", "ateliês encontrados" do
        schema SELLER_LIST_SCHEMA

        let!(:product) { Product.create!(seller: approved_seller, name: "Vaso ateliê spec", sku: "RSWAG-SELLER-001", price_cents: 8990, stock_quantity: 3, status: :active) }

        run_test! do |response|
          body = JSON.parse(response.body)
          listed = body["sellers"].find { |s| s["slug"] == approved_seller.slug }

          expect(listed).to be_present
          expect(listed["product_count"]).to eq(1)
        end
      end

      # Descrição/schema repetidos de propósito nos blocos de mesmo status:
      # o rswag mescla todos num só objeto de resposta no swagger.yaml.
      response "200", "ateliês encontrados" do
        schema SELLER_LIST_SCHEMA

        let!(:pending_seller) { Seller.create!(name: "Ateliê pendente spec", status: :pending) }
        let!(:pending_product) { Product.create!(seller: pending_seller, name: "Peça pendente spec", sku: "RSWAG-PENDING-001", price_cents: 5000, stock_quantity: 2, status: :active) }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["sellers"].map { |s| s["slug"] }).not_to include(pending_seller.slug)
        end
      end

      response "200", "ateliês encontrados" do
        schema SELLER_LIST_SCHEMA

        # Aprovado, mas sem nada publicado: a vitrine dele seria um beco.
        let!(:empty_seller) { Seller.create!(name: "Ateliê vazio spec", status: :approved, approved_at: Time.current) }
        let!(:draft_product) { Product.create!(seller: empty_seller, name: "Rascunho spec", sku: "RSWAG-EMPTY-001", price_cents: 5000, stock_quantity: 2, status: :draft) }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["sellers"].map { |s| s["slug"] }).not_to include(empty_seller.slug)
        end
      end
    end
  end

  path "/api/v1/sellers/{slug}" do
    get "Exibe um ateliê aprovado pelo slug" do
      tags "Sellers"
      produces "application/json"
      parameter name: :slug, in: :path, type: :string

      response "200", "ateliê encontrado" do
        schema SELLER_SCHEMA

        let!(:product) { Product.create!(seller: approved_seller, name: "Vaso ateliê show spec", sku: "RSWAG-SELLER-SHOW-001", price_cents: 8990, stock_quantity: 3, status: :active) }
        let(:slug) { approved_seller.slug }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["slug"]).to eq(approved_seller.slug)
          expect(body["product_count"]).to eq(1)
        end
      end

      response "404", "ateliê não encontrado ou não aprovado" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:slug) { "atelie-que-nao-existe" }

        run_test!
      end

      response "404", "ateliê não encontrado ou não aprovado" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let!(:suspended_seller) { Seller.create!(name: "Ateliê suspenso spec", status: :suspended) }
        let(:slug) { suspended_seller.slug }

        run_test!
      end
    end
  end
end
