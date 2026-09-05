# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Storefront products", type: :request do
  before do
    clear_product_data!
  end

  describe "GET /produtos" do
    it "lists only active products" do
      active = Product.create!(seller: approved_seller, name: "Vaso ativo", sku: "STORE-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      draft = Product.create!(seller: approved_seller, name: "Caneca rascunho", sku: "STORE-002", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :draft)

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).not_to include(draft.name)
    end

    it "does not list active products from a seller awaiting approval" do
      pending_seller = Seller.create!(name: "Ateliê em análise")
      product = Product.create!(seller: pending_seller, name: "Peça pendente", sku: "STORE-PENDING-001", price_cents: 8_990, stock_quantity: 1, currency: "BRL", status: :active)

      get products_path

      expect(response.body).not_to include(product.name)
    end

    it "sets a generic title and description on the unfiltered catalog" do
      get products_path

      expect(response.body).to include("<title>Loja | EloShop")
      expect(response.body).to include('<meta name="description"')
    end

    it "orders by price when the shopper picks a price sort" do
      cheap = Product.create!(seller: approved_seller, name: "Vaso barato", sku: "STORE-010", price_cents: 1_000, stock_quantity: 3, currency: "BRL", status: :active)
      expensive = Product.create!(seller: approved_seller, name: "Vaso caro", sku: "STORE-011", price_cents: 9_000, stock_quantity: 3, currency: "BRL", status: :active)

      get products_path(sort: "menor-preco")
      expect(response.body.index(cheap.name)).to be < response.body.index(expensive.name)

      get products_path(sort: "maior-preco")
      expect(response.body.index(expensive.name)).to be < response.body.index(cheap.name)
    end

    it "shows the atelier of each product on the listing" do
      product = Product.create!(seller: approved_seller, name: "Vaso da listagem", sku: "LIST-ATL", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      get products_path

      expect(response.body).to include(product.name)
      expect(response.body).to include(product.seller.name)
    end

    it "filters the catalog by atelier" do
      other = Seller.create!(name: "Ateliê do filtro #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      mine = Product.create!(seller: approved_seller, name: "Peça do meu ateliê", sku: "FIL-A", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)
      theirs = Product.create!(seller: other, name: "Peça do outro ateliê", sku: "FIL-B", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)

      get products_path, params: { seller: approved_seller.slug }

      expect(response.body).to include(mine.name)
      expect(response.body).not_to include(theirs.name)
    end

    it "offers only ateliers that have something for sale in the filter" do
      empty = Seller.create!(name: "Ateliê sem peça #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      Product.create!(seller: approved_seller, name: "Peça à venda", sku: "FIL-C", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)

      get products_path

      expect(response.body).to include(approved_seller.name)
      expect(response.body).not_to include(empty.name)
    end

    it "keeps the atelier filter when the sort changes" do
      Product.create!(seller: approved_seller, name: "Peça ordenada", sku: "FIL-D", price_cents: 5_000, stock_quantity: 2, currency: "BRL", status: :active)

      get products_path, params: { seller: approved_seller.slug, sort: "nome" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Peça ordenada")
    end

    it "falls back to the default sort when the sort param is not on the allowed list" do
      older = Product.create!(seller: approved_seller, name: "Vaso antigo", sku: "STORE-012", price_cents: 1_000, stock_quantity: 3, currency: "BRL", status: :active, created_at: 2.days.ago)
      newer = Product.create!(seller: approved_seller, name: "Vaso novo", sku: "STORE-013", price_cents: 9_000, stock_quantity: 3, currency: "BRL", status: :active, created_at: 1.hour.ago)

      get products_path(sort: "price_cents asc; drop table products")

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.name)).to be < response.body.index(older.name)
    end

    it "honors a page size from the allowed list" do
      3.times { |i| Product.create!(seller: approved_seller, name: "Vaso paginado #{i}", sku: "STORE-02#{i}", price_cents: 1_000, stock_quantity: 3, currency: "BRL", status: :active) }

      get products_path(per_page: 8)

      expect(response.body).to include("Mostrando 1–3 de 3 resultados")
    end

    it "ignores a page size outside the allowed list" do
      13.times { |i| Product.create!(seller: approved_seller, name: "Vaso limite #{i}", sku: "STORE-1#{i.to_s.rjust(2, "0")}", price_cents: 1_000, stock_quantity: 3, currency: "BRL", status: :active) }

      get products_path(per_page: 500)

      expect(response.body).to include("Mostrando 1–12 de 13 resultados")
    end

    it "sets a category-specific title when filtered by category" do
      category = Category.create!(name: "Decoração SEO")
      Product.create!(seller: approved_seller, name: "Vaso categoria seo", sku: "STORE-005", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active, category: category)

      get products_path(category: category.slug)

      expect(response.body).to include("<title>#{category.breadcrumb_name} | EloShop")
    end
  end

  describe "GET /produtos/:slug" do
    it "renders an active product by slug" do
      product = Product.create!(seller: approved_seller, name: "Vaso storefront", sku: "STORE-003", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      get product_path(product.seller, product.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end

    # Quem compra artesanato quer saber de quem é a mão: o ateliê aparece
    # junto do produto, não só na URL.
    # (o mesmo vale na listagem — ver o exemplo em "GET /produtos")
    it "shows the atelier that made the product" do
      product = Product.create!(seller: approved_seller, name: "Vaso do ateliê", sku: "STORE-ATL", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      get product_path(product.seller, product.slug)

      expect(response.body).to include("Feito por")
      expect(response.body).to include(product.seller.name)
    end

    it "returns 404 for a draft product" do
      product = Product.create!(seller: approved_seller, name: "Caneca draft", sku: "STORE-004", price_cents: 4_990, stock_quantity: 5, currency: "BRL", status: :draft)

      get product_path(product.seller, product.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "sets title, meta description, canonical URL and Open Graph tags" do
      product = Product.create!(seller: approved_seller, name: "Vaso SEO", sku: "STORE-006", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active, description: "Vaso de cerâmica feito à mão.")

      get product_path(product.seller, product.slug)

      expect(response.body).to include("<title>Vaso SEO | EloShop</title>")
      expect(response.body).to include('<meta name="description" content="Vaso de cerâmica feito à mão.">')
      expect(response.body).to include(%(<link rel="canonical" href="#{product_url(product.seller, product.slug)}">))
      expect(response.body).to include('<meta property="og:type" content="product">')
      expect(response.body).to include('<meta property="og:title" content="Vaso SEO | EloShop">')
    end

    it "includes Product structured data (JSON-LD)" do
      product = Product.create!(seller: approved_seller, name: "Vaso JSON-LD", sku: "STORE-007", price_cents: 12_345, stock_quantity: 3, currency: "BRL", status: :active)

      get product_path(product.seller, product.slug)

      json = response.body[/<script type="application\/ld\+json">(.*?)<\/script>/m, 1]
      data = JSON.parse(json)

      expect(data["@type"]).to eq("Product")
      expect(data["name"]).to eq("Vaso JSON-LD")
      expect(data["sku"]).to eq(product.sku)
      # No marketplace quem assina a peça é o ateliê, não a plataforma.
      expect(data["brand"]).to eq({ "@type" => "Brand", "name" => product.seller.name })
      expect(data["offers"]["price"]).to eq(123.45)
      expect(data["offers"]["availability"]).to eq("https://schema.org/InStock")
    end

    it "marks unavailable products as OutOfStock in structured data" do
      product = Product.create!(seller: approved_seller, name: "Vaso esgotado seo", sku: "STORE-008", price_cents: 8_990, stock_quantity: 0, currency: "BRL", status: :active)

      get product_path(product.seller, product.slug)

      json = response.body[/<script type="application\/ld\+json">(.*?)<\/script>/m, 1]
      data = JSON.parse(json)

      expect(data["offers"]["availability"]).to eq("https://schema.org/OutOfStock")
    end
  end

  describe "GET /produtos/:slug legacy URL" do
    it "permanently redirects an unambiguous legacy slug to its seller URL" do
      product = Product.create!(seller: approved_seller, name: "Vaso legado", sku: "STORE-LEGACY-001", price_cents: 8_990, stock_quantity: 1, currency: "BRL", status: :active)

      get legacy_product_path(product.slug)

      expect(response).to redirect_to(product_path(product.seller, product.slug))
      expect(response).to have_http_status(:moved_permanently)
    end
  end
  describe "custo de consulta" do
    # O filtro lateral do catálogo mostra o breadcrumb de cada categoria, e
    # resolvê-lo pelo Active Record custava uma query por nível, por
    # categoria. A asserção é sobre o crescimento, não sobre um total
    # absoluto: o número muda quando a página muda, a inclinação é que não
    # pode voltar.
    it "does not grow the catalog query count when categories are added" do
      Product.create!(seller: approved_seller, name: "Vaso do custo", sku: "PERF-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)
      Category.create!(name: "Casa do custo").children.create!(name: "Decoração do custo")

      get products_path
      before = count_queries { get products_path }

      raiz = Category.create!(name: "Moda do custo")
      filha = raiz.children.create!(name: "Bolsas do custo")
      filha.children.create!(name: "Bolsas de couro do custo")

      get products_path
      after = count_queries { get products_path }

      expect(after).to eq(before)
    end

    # A capa dos cards é carregada com preload, não com includes. Com includes,
    # o `distinct` do catálogo obriga o Active Record a resolver tudo numa
    # única SELECT DISTINCT, e o anexo arrasta as tabelas de variante do
    # Active Storage: 15 JOINs e ~130 colunas. A execução continua trivial
    # (Unique em 0,03 ms), mas o custo *estimado* do plano passa do
    # jit_above_cost e o PostgreSQL compila 120 funções por execução — ~1240 ms
    # a cada requisição, medido em produção como 1012 ms (p50) no /produtos.
    #
    # A asserção é sobre a forma da query, não sobre tempo: tempo depende da
    # máquina, e o teste viraria ruído. Uma SELECT DISTINCT que já traga as
    # colunas do blob junto é exatamente a forma que reintroduz o problema.
    it "loads the cover image without folding Active Storage into the DISTINCT query" do
      Product.create!(seller: approved_seller, name: "Vaso da capa", sku: "PERF-002", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

      queries = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] unless payload[:name].to_s.in?(QueryHelpers::IGNORED) || payload[:cached]
      end
      get products_path
      ActiveSupport::Notifications.unsubscribe(subscription)

      distinct_queries = queries.select { |sql| sql.include?("SELECT DISTINCT") }
      expect(distinct_queries).not_to be_empty
      expect(distinct_queries).to all(satisfy { |sql| !sql.include?("active_storage_variant_records") })
    end

    # O contraponto do teste acima: separar a capa em preload não pode
    # reintroduzir uma query por card.
    it "does not grow the catalog query count when products are added" do
      3.times { |i| Product.create!(seller: approved_seller, name: "Vaso serie #{i}", sku: "PERF-1#{i}", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }

      get products_path
      before = count_queries { get products_path }

      3.times { |i| Product.create!(seller: approved_seller, name: "Vaso extra #{i}", sku: "PERF-2#{i}", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }

      get products_path
      after = count_queries { get products_path }

      expect(after).to eq(before)
    end
  end
end
