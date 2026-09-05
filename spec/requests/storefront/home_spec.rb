# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Storefront home", type: :request do
  before do
    clear_product_data!
  end

  describe "GET /" do
    # A home não é mais só o carrossel: a seção "Destaques" lista os
    # produtos mais recentes (ver "shows the newest products" abaixo), então
    # um produto qualquer pode aparecer ali. O que este teste protege é que a
    # home não vira um catálogo completo — sem paginação, sem filtro, sem a
    # grade cheia de produtos que só `/produtos` deve mostrar.
    it "renders the storefront presentation with a link to the full catalog" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Peças com história, feitas à mão")
      expect(response.body).to include(products_path)
    end

    # O carrossel é progressivo: os dois banners vêm no HTML e continuam
    # alcançáveis pela rolagem da faixa mesmo sem JavaScript.
    it "renders the artisan banner with its call to action" do
      get root_path

      expect(response.body).to include("Para o Artesão")
      expect(response.body).to include("Venda suas peças mais criativas através do nosso Ateliê")
      expect(response.body).to include("Seja um artesão")
      expect(response.body).to include(new_seller_registration_path)
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

    it "uses the newest active product of the subtree as the category cover" do
      parent = Category.create!(name: "Casa da capa")
      child = Category.create!(name: "Cozinha da capa", parent: parent)

      product_with_cover(category: child, sku: "COVER-OLD", filename: "antiga.png", created_at: 2.days.ago)
      product_with_cover(category: parent, sku: "COVER-NEW", filename: "recente.png", created_at: 1.hour.ago)

      get root_path

      # Escopado à faixa de categorias: a seção "Destaques" também lista
      # produtos recentes e pode legitimamente exibir a mesma imagem — o que
      # importa aqui é qual delas é a capa da categoria, não se a string
      # aparece em algum lugar da página inteira.
      category_section = Nokogiri::HTML(response.body).at_css("section:has(h2:contains('Explore por categoria'))")
      expect(category_section.to_html).to include("recente.png")
      expect(category_section.to_html).not_to include("antiga.png")
    end

    it "falls back to an older product when the newest one has no image" do
      category = Category.create!(name: "Sala da capa")

      product_with_cover(category: category, sku: "COVER-IMG", filename: "com-foto.png", created_at: 2.days.ago)
      Product.create!(seller: approved_seller, name: "Sem foto", sku: "COVER-NOIMG", price_cents: 1_000, stock_quantity: 1,
                      currency: "BRL", status: :active, category: category, created_at: 1.hour.ago)

      get root_path

      expect(response.body).to include("com-foto.png")
    end

    it "ignores products that are not active" do
      category = Category.create!(name: "Quarto da capa")

      product_with_cover(category: category, sku: "COVER-DRAFT", filename: "rascunho.png",
                         created_at: 1.hour.ago, status: :draft)

      get root_path

      expect(response.body).not_to include("rascunho.png")
    end

    # O custo da home crescia 5 queries por categoria de topo: cada capa era
    # buscada sozinha e arrastava anexo, blob e variant records atrás de si.
    # A asserção é sobre a invariante, não sobre um número absoluto — o total
    # muda quando a página muda, o crescimento com o catálogo é que não pode
    # voltar.
    #
    # A seção "Destaques" busca até 6 produtos recentes com preload próprio: o
    # LIMIT já é fixo, mas o número de linhas que o preload de fato carrega
    # muda enquanto o catálogo tem menos de 6 produtos publicados — 6
    # produtos "sobrando" antes de medir satura esse limite nas duas
    # rodadas, isolando a asserção do efeito de categoria que ela protege.
    it "does not issue more queries when another top-level category is added" do
      6.times { |i| product_with_cover(category: Category.create!(name: "Base #{i}"), sku: "BASE-#{i}", filename: "base#{i}.png") }

      2.times { |i| product_with_cover(category: Category.create!(name: "Topo #{i}"), sku: "COVER-N#{i}", filename: "topo#{i}.png") }
      get root_path
      before = count_queries { get root_path }

      3.upto(6) { |i| product_with_cover(category: Category.create!(name: "Topo #{i}"), sku: "COVER-N#{i}", filename: "topo#{i}.png") }
      get root_path
      after = count_queries { get root_path }

      expect(after).to eq(before)
    end
  end

  def product_with_cover(category:, sku:, filename:, created_at: Time.current, status: :active)
    product = Product.create!(seller: approved_seller, name: "Produto #{sku}", sku: sku, price_cents: 5_000, stock_quantity: 2,
                              currency: "BRL", status: status, category: category, created_at: created_at)
    product.main_image.attach(io: file_fixture("sample.png").open, filename: filename, content_type: "image/png")
    product
  end
end
