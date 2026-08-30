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

  LIST_SCHEMA = {
    type: :object,
    properties: {
      products: { type: :array, items: PRODUCT_SCHEMA },
      page: { type: :integer },
      total_pages: { type: :integer }
    },
    required: %w[products page total_pages]
  }.freeze

  path "/api/v1/products" do
    get "Lista produtos ativos" do
      tags "Products"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false,
                description: "Página da listagem (padrão 1)"

      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        let!(:active_product) { Product.create!(name: "Vaso rswag spec", sku: "RSWAG-VASO-001", price_cents: 8990, stock_quantity: 3, status: :active) }
        let!(:draft_product) { Product.create!(name: "Caneca rswag spec", sku: "RSWAG-CANECA-001", price_cents: 4990, stock_quantity: 5, status: :draft) }

        run_test! do |response|
          body = JSON.parse(response.body)
          slugs = body["products"].map { |p| p["slug"] }

          expect(slugs).to include(active_product.slug)
          expect(slugs).not_to include(draft_product.slug)
        end
      end

      # Descrição igual à do primeiro response "200" acima de propósito: o
      # OpenAPI só permite um objeto de resposta por status code, então o
      # rswag mescla todos os blocos "200" desta rota num só ao gerar o
      # swagger.yaml (o texto do último bloco executado prevalece). Manter a
      # mesma descrição/schema em todos evita que a documentação gerada mude
      # de forma imprevisível conforme a ordem de execução dos testes —
      # cada bloco cobre um cenário de negócio diferente internamente.
      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        let!(:sold_out_product) { Product.create!(name: "Vaso esgotado rswag spec", sku: "RSWAG-SOLDOUT-001", price_cents: 8990, stock_quantity: 0, status: :sold_out) }

        run_test! do |response|
          body = JSON.parse(response.body)
          slugs = body["products"].map { |p| p["slug"] }

          expect(slugs).not_to include(sold_out_product.slug)
        end
      end

      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        let!(:discontinued_product) { Product.create!(name: "Produto descontinuado rswag spec", sku: "RSWAG-DISC-001", price_cents: 3990, stock_quantity: 0, status: :discontinued) }

        run_test! do |response|
          body = JSON.parse(response.body)
          slugs = body["products"].map { |p| p["slug"] }

          expect(slugs).not_to include(discontinued_product.slug)
        end
      end

      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        # Isola a contagem de páginas de qualquer produto ativo pré-existente
        # no banco (seed/outros testes), já que este cenário depende do total exato.
        before { Product.active.update_all(status: "discontinued") }

        let!(:products) do
          13.times.map do |i|
            Product.create!(
              name: "Produto paginação rswag #{i}",
              sku: "RSWAG-PAGE-#{i}",
              price_cents: 1000 + i,
              stock_quantity: 3,
              status: :active,
              created_at: i.hours.ago
            )
          end
        end
        let(:page) { 2 }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["page"]).to eq(2)
          expect(body["total_pages"]).to eq(2)
          expect(body["products"].size).to eq(1)
          expect(body["products"].first["slug"]).to eq(products.last.slug)
        end
      end

      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        let!(:variant_product) { Product.create!(name: "Camiseta rswag spec", sku: "RSWAG-CAMISETA-001", price_cents: 5000, stock_quantity: 0, status: :active) }
        let!(:cheaper_variant) { ProductVariant.create!(product: variant_product, sku: "RSWAG-CAMISETA-001-P", price_cents: 4200, stock_quantity: 2, active: true, size: "P") }
        let!(:pricier_variant) { ProductVariant.create!(product: variant_product, sku: "RSWAG-CAMISETA-001-G", price_cents: 4800, stock_quantity: 2, active: true, size: "G") }

        run_test! do |response|
          body = JSON.parse(response.body)
          product_json = body["products"].find { |p| p["slug"] == variant_product.slug }

          expect(product_json["price_cents"]).to eq(4200)
        end
      end

      response "200", "produtos ativos encontrados" do
        schema LIST_SCHEMA

        let!(:made_to_order_product) do
          Product.create!(
            name: "Luminária sob encomenda rswag spec",
            sku: "RSWAG-MTO-001",
            price_cents: 15_000,
            stock_quantity: 0,
            status: :active,
            availability_type: :made_to_order,
            production_time_min_days: 7,
            production_time_max_days: 10
          )
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          product_json = body["products"].find { |p| p["slug"] == made_to_order_product.slug }

          expect(product_json["availability_type"]).to eq("made_to_order")
          expect(product_json["production_time_range"]).to eq("7 a 10 dias úteis")
          expect(product_json["available_for_purchase"]).to eq(true)
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

      # Mesma observação do path de listagem acima: descrição/schema
      # repetidos de propósito em todos os blocos "404"/"200" desta rota,
      # já que o rswag só mantém um objeto de resposta por status code no
      # swagger.yaml gerado (o último bloco executado prevalece).
      response "404", "produto não encontrado ou não disponível publicamente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:slug) { "produto-que-nao-existe" }

        run_test!
      end

      response "404", "produto não encontrado ou não disponível publicamente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:draft_product) { Product.create!(name: "Caneca rswag spec", sku: "RSWAG-CANECA-001", price_cents: 4990, stock_quantity: 5, status: :draft) }
        let(:slug) { draft_product.slug }

        run_test!
      end

      response "404", "produto não encontrado ou não disponível publicamente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:sold_out_product) { Product.create!(name: "Vaso esgotado rswag show", sku: "RSWAG-SOLDOUT-SHOW-001", price_cents: 8990, stock_quantity: 0, status: :sold_out) }
        let(:slug) { sold_out_product.slug }

        run_test!
      end

      response "404", "produto não encontrado ou não disponível publicamente" do
        schema type: :object, properties: { error: { type: :string } }, required: %w[error]

        let(:discontinued_product) { Product.create!(name: "Produto descontinuado rswag show", sku: "RSWAG-DISC-SHOW-001", price_cents: 3990, stock_quantity: 0, status: :discontinued) }
        let(:slug) { discontinued_product.slug }

        run_test!
      end

      response "200", "produto encontrado" do
        schema PRODUCT_SCHEMA

        let!(:variant_product) { Product.create!(name: "Camiseta rswag show spec", sku: "RSWAG-CAMISETA-SHOW-001", price_cents: 5000, stock_quantity: 0, status: :active) }
        let!(:cheaper_variant) { ProductVariant.create!(product: variant_product, sku: "RSWAG-CAMISETA-SHOW-001-P", price_cents: 4200, stock_quantity: 2, active: true, size: "P") }
        let!(:pricier_variant) { ProductVariant.create!(product: variant_product, sku: "RSWAG-CAMISETA-SHOW-001-G", price_cents: 4800, stock_quantity: 2, active: true, size: "G") }
        let(:slug) { variant_product.slug }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["price_cents"]).to eq(4200)
        end
      end

      response "200", "produto encontrado" do
        schema PRODUCT_SCHEMA

        let(:made_to_order_product) do
          Product.create!(
            name: "Luminária sob encomenda rswag show",
            sku: "RSWAG-MTO-SHOW-001",
            price_cents: 15_000,
            stock_quantity: 0,
            status: :active,
            availability_type: :made_to_order,
            production_time_min_days: 7,
            production_time_max_days: 10
          )
        end
        let(:slug) { made_to_order_product.slug }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["availability_type"]).to eq("made_to_order")
          expect(body["production_time_range"]).to eq("7 a 10 dias úteis")
        end
      end
    end
  end
end
