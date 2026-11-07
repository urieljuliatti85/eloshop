require "swagger_helper"

RSpec.describe "api/v1/supplies", type: :request do
  let(:Authorization) { "Bearer #{api_token}" }

  def approved_distributor
    @approved_distributor ||= Seller.create!(name: "Armarinho API #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf, kind: "distributor", status: :approved, approved_at: Time.current)
  end

  SUPPLY_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer }, name: { type: :string }, slug: { type: :string },
      seller: { type: :object, properties: { name: { type: :string }, slug: { type: :string } }, required: %w[name slug] },
      description: { type: :string, nullable: true }, price_cents: { type: :integer }, currency: { type: :string },
      sale_unit: { type: :string, enum: %w[unit pack meter kilogram roll box] }, sale_unit_name: { type: :string },
      sale_unit_detail: { type: :string, nullable: true }, min_order_quantity: { type: :integer },
      price_tiers: { type: :array, items: { type: :object, properties: { min_quantity: { type: :integer }, discount_bps: { type: :integer }, price_cents: { type: :integer } }, required: %w[min_quantity discount_bps price_cents] } },
      available_for_purchase: { type: :boolean }
    }, required: %w[id name slug seller price_cents currency sale_unit sale_unit_name min_order_quantity price_tiers available_for_purchase]
  }.freeze

  path "/api/v1/supplies" do
    get "Lista insumos publicados" do
      tags "Supplies"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false
      documents_api_token_requirement
      documents_rate_limit

      response "400", "parâmetro inválido" do
        schema type: :object, properties: { error: { type: :string }, parameter: { type: :string } }, required: %w[error parameter]
        let(:page) { "0" }
        run_test! do |response|
          expect(JSON.parse(response.body)).to eq("error" => "invalid_parameter", "parameter" => "page")
        end
      end

      response "200", "insumos encontrados" do
        schema type: :object, properties: {
          supplies: { type: :array, items: SUPPLY_SCHEMA }, page: { type: :integer },
          total_pages: { type: :integer }, total_count: { type: :integer }
        }, required: %w[supplies page total_pages total_count]

        let!(:supply) { Product.create!(seller: approved_distributor, name: "Fio API", sku: "API-FIO-1", price_cents: 2500, stock_quantity: 20, status: :active, sale_unit: :pack, min_order_quantity: 2) }
        run_test! do |response|
          item = JSON.parse(response.body).fetch("supplies").find { |entry| entry["slug"] == supply.slug }
          expect(item).to include("sale_unit" => "pack", "min_order_quantity" => 2, "price_tiers" => [])
        end
      end
    end
  end

  path "/api/v1/armarinhos/{seller_slug}/supplies/{slug}" do
    get "Exibe um insumo publicado" do
      tags "Supplies"
      produces "application/json"
      parameter name: :seller_slug, in: :path, type: :string
      parameter name: :slug, in: :path, type: :string
      let(:seller_slug) { approved_distributor.slug }
      documents_api_token_requirement slug: "qualquer-insumo"
      documents_rate_limit slug: "qualquer-insumo"

      response "200", "insumo encontrado" do
        schema SUPPLY_SCHEMA
        let!(:supply) { Product.create!(seller: approved_distributor, name: "Fio API detalhe", sku: "API-FIO-2", price_cents: 2500, stock_quantity: 20, status: :active, sale_unit: :pack, min_order_quantity: 2) }
        let(:slug) { supply.slug }
        run_test!
      end

      response "404", "insumo não encontrado ou não disponível publicamente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]
        let(:slug) { "insumo-inexistente" }
        run_test!
      end
    end
  end
end
