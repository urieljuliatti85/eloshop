# frozen_string_literal: true

require "rails_helper"

# Faixa de categorias com dropdown pai > filhas e busca com autocomplete de
# produtos dentro da categoria escolhida.
RSpec.describe "Storefront category filter", type: :request do
  before { clear_product_data! }

  let!(:casa) { Category.create!(name: "Casa") }
  let!(:cozinha) { casa.children.create!(name: "Cozinha") }
  let!(:decoracao) { casa.children.create!(name: "Decoração") }
  let!(:infantil) { Category.create!(name: "Infantil") }
  let!(:moda) { Category.create!(name: "Moda") }
  let!(:roupas) { moda.children.create!(name: "Roupas") }

  def create_product(name:, category: nil, **attrs)
    Product.create!({ seller: approved_seller, name: name, sku: "CF-#{SecureRandom.hex(4)}", price_cents: 4_990,
                      stock_quantity: 3, currency: "BRL", status: :active, category: category }.merge(attrs))
  end

  describe "GET /produtos" do
    let(:doc) { Nokogiri::HTML(response.body) }
    let(:menu) { doc.at_css("nav[aria-label='Categorias']") }

    it "opens on the whole catalog, with no category selected" do
      create_product(name: "Vaso da casa", category: cozinha)
      create_product(name: "Camiseta lisa", category: roupas)

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vaso da casa", "Camiseta lisa")
      expect(doc.at_css("select#search-category option[selected]")).to be_nil
    end

    it "keeps a single control in the category strip: the 'Ver todos' button" do
      get products_path

      controls = menu.xpath("./a | ./button | ./div/button | ./div/a").map { |node| node.text.squish }

      expect(controls).to eq([ "Ver todos" ])
    end

    it "no longer shows the 'Todos' button or one pill per category" do
      get products_path

      expect(menu.css("button[data-account-menu-target='button']").map { |node| node.text.squish }).to eq([ "Ver todos" ])
      expect(menu.css("a").map { |node| node.text.squish }).not_to include("Todos")
      expect(menu.text).not_to include("Casa > Cozinha")
    end

    it "offers the same categories, grouped by parent, in the search dropdown" do
      get products_path

      select = doc.at_css("select#search-category")

      expect(select.at_css("option")["value"]).to eq("")
      group = select.at_css("optgroup[label='Casa']")
      expect(group.css("option").map { |option| option.text.squish }).to eq([ "Todos em Casa", "Cozinha", "Decoração" ])
      expect(select.css("option[value='infantil']")).to be_present
    end

    it "wires the search box as an accessible combobox with a suggestions endpoint" do
      get products_path

      form = doc.at_css("form[data-controller='product-autocomplete']")

      expect(form["role"]).to eq("search")
      expect(form["data-product-autocomplete-url-value"]).to eq(suggestions_products_path)
      input = form.at_css("input[name='q']")
      expect(input["role"]).to eq("combobox")
      expect(input["aria-controls"]).to eq("search-suggestions")
      expect(form.at_css("ul#search-suggestions[role='listbox']")).to be_present
    end
  end

  describe "the 'Ver todos' menu" do
    let(:doc) { Nokogiri::HTML(response.body) }
    let(:browser) { doc.at_css("nav[aria-label='Categorias'] [data-controller~='category-flyout']") }

    before { get products_path }

    it "starts the menu with 'Todos os produtos', the way back to the whole catalog" do
      first = browser.at_css("[data-account-menu-target='panel'] > ul > li")

      expect(first.at_css("a").text.squish).to eq("Todos os produtos")
      expect(first.at_css("a")["href"]).to eq(products_path)
    end

    it "lists every top-level category in one column, with children behind the ones that have them" do
      entries = browser.css("[data-account-menu-target='panel'] > ul > li").map { |item| item.at_css("button, a").text.squish }

      expect(entries).to eq([ "Todos os produtos", "Casa", "Infantil", "Moda" ])
      expect(browser.css("button[data-category-flyout-target='root']").map { |node| node.text.squish }).to eq([ "Casa", "Moda" ])
      expect(browser.css("a").map { |node| node["href"] }).to include(products_path(category: "infantil"))
    end

    it "keeps each submenu hidden, with the children and 'Ver tudo' beside it" do
      casa_list = browser.at_css("ul[data-category-flyout-target='children'][id='browse-casa']")

      expect(casa_list.has_attribute?("hidden")).to be(true)
      expect(casa_list.css("a").map { |node| node.text.squish }).to eq([ "Ver tudo em Casa", "Cozinha", "Decoração" ])
      expect(casa_list.css("a").map { |node| node["href"] }).to include(products_path(category: "decoracao"))
    end

    it "links each root button to its submenu for assistive technology" do
      button = browser.at_css("button[data-category-flyout-target='root'][aria-controls='browse-casa']")

      expect(button["aria-expanded"]).to eq("false")
      expect(browser.at_css("##{button['aria-controls']}")).to be_present
    end

    it "starts on the category being browsed" do
      get products_path(category: "roupas")

      browser = Nokogiri::HTML(response.body).at_css("[data-controller~='category-flyout']")
      expect(browser["data-category-flyout-current-value"]).to eq(moda.id.to_s)
    end

    it "does not offer a disabled category or its children" do
      moda.update!(active: false)

      get products_path

      browser = Nokogiri::HTML(response.body).at_css("[data-controller~='category-flyout']")
      expect(browser.text).not_to include("Moda")
      expect(browser.text).not_to include("Roupas")
    end
  end

  describe "hashtags" do
    it "no longer shows the tag strip on the catalog, but keeps the tag filter in the URL" do
      tag = Tag.create!(name: "feito-a-mao")
      tagged = create_product(name: "Vaso com tag", category: casa)
      tagged.tags << tag
      create_product(name: "Vaso sem tag", category: casa)

      get products_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("nav[aria-label='Tags']")).to be_nil
      expect(response.body).not_to include("#feito-a-mao")

      get products_path(tag: "feito-a-mao")

      expect(response.body).to include("Vaso com tag")
      expect(response.body).not_to include("Vaso sem tag")
    end
  end

  describe "GET /produtos with a category" do
    it "highlights the parent in the menu when the current category is one of its children" do
      get products_path(category: "cozinha")

      doc = Nokogiri::HTML(response.body)
      casa_root = doc.at_css("[data-controller~='category-flyout'] button[data-category-flyout-target='root'][aria-controls='browse-casa']")
      expect(casa_root["class"]).to include("bg-brand-50")
      cozinha_link = doc.at_css("#browse-casa a[href='#{products_path(category: 'cozinha')}']")
      expect(cozinha_link["aria-current"]).to eq("true")
      expect(doc.at_css("select#search-category option[value='cozinha']")["selected"]).to be_present
    end

    it "marks 'Todos os produtos' as the current entry only when no category is selected" do
      get products_path
      expect(Nokogiri::HTML(response.body).at_css("[data-controller~='category-flyout'] a[href='#{products_path}']")["aria-current"]).to eq("true")

      get products_path(category: "casa")
      expect(Nokogiri::HTML(response.body).at_css("[data-controller~='category-flyout'] a[href='#{products_path}']")["aria-current"]).to be_nil
    end

    it "does not offer a disabled category or a child of a disabled one" do
      moda.update!(active: false)

      get products_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("nav[aria-label='Categorias']").text).not_to include("Moda")
      expect(doc.css("select#search-category option").map { |option| option["value"] }).not_to include("moda", "roupas")
    end

    it "keeps the other filters when the shopper picks a category in the search" do
      get products_path(sort: "menor-preco", seller: "ateliê", q: "vaso", category: "casa")

      form = Nokogiri::HTML(response.body).at_css("form[data-controller='product-autocomplete']")
      hidden = form.css("input[type='hidden']").to_h { |node| [ node["name"], node["value"] ] }
      expect(hidden).to include("sort" => "menor-preco", "seller" => "ateliê")
      expect(hidden.keys).not_to include("q", "category", "page")
    end
  end

  describe "GET /produtos/sugestoes" do
    def suggestions(**params)
      get suggestions_products_path(params), headers: { "Accept" => "application/json" }
      response.parsed_body["suggestions"]
    end

    it "suggests visible products matching the text, with the product link" do
      vaso = create_product(name: "Vaso de cerâmica", category: decoracao)

      result = suggestions(q: "vaso")

      expect(result.map { |item| item["name"] }).to eq([ "Vaso de cerâmica" ])
      expect(result.first["url"]).to eq(product_path(vaso.seller, vaso.slug))
      expect(result.first["category"]).to eq("Casa > Decoração")
    end

    it "limits the suggestions to the category picked in the dropdown, including its children" do
      create_product(name: "Vaso da cozinha", category: cozinha)
      create_product(name: "Vaso de moda", category: roupas)

      expect(suggestions(q: "vaso", category: "casa").map { |item| item["name"] }).to eq([ "Vaso da cozinha" ])
      expect(suggestions(q: "vaso", category: "cozinha").map { |item| item["name"] }).to eq([ "Vaso da cozinha" ])
      expect(suggestions(q: "vaso", category: "moda").map { |item| item["name"] }).to eq([ "Vaso de moda" ])
      expect(suggestions(q: "vaso").size).to eq(2)
    end

    it "returns nothing for an unknown or disabled category" do
      create_product(name: "Vaso qualquer", category: roupas)
      moda.update!(active: false)

      expect(suggestions(q: "vaso", category: "inexistente")).to eq([])
      expect(suggestions(q: "vaso", category: "moda")).to eq([])
    end

    it "does not suggest drafts, products of sellers awaiting approval or of disabled categories" do
      create_product(name: "Vaso rascunho", status: :draft)
      pending_seller = Seller.create!(name: "Ateliê em análise", owner_full_name: "Proprietário Teste", cpf: "13888909503")
      create_product(name: "Vaso pendente", seller: pending_seller)
      moda.update!(active: false)
      create_product(name: "Vaso escondido", category: roupas)
      create_product(name: "Vaso visível", category: casa)

      expect(suggestions(q: "vaso").map { |item| item["name"] }).to eq([ "Vaso visível" ])
    end

    it "waits for at least two characters" do
      create_product(name: "Vaso", category: casa)

      expect(suggestions(q: "v")).to eq([])
      expect(suggestions(q: " ")).to eq([])
      expect(suggestions).to eq([])
    end

    it "caps the list at eight suggestions" do
      10.times { |index| create_product(name: "Vaso #{index}", category: casa) }

      expect(suggestions(q: "vaso").size).to eq(ProductsController::SUGGESTION_LIMIT)
    end

    it "treats LIKE wildcards in the text literally" do
      create_product(name: "Vaso azul", category: casa)

      expect(suggestions(q: "%%")).to eq([])
    end

    it "does not break on a text that looks like SQL" do
      create_product(name: "Vaso azul", category: casa)

      expect(suggestions(q: "'; DROP TABLE products; --")).to eq([])
      expect(Product.count).to eq(1)
    end

    it "answers 429 when the shopper hammers the endpoint" do
      61.times { get suggestions_products_path(q: "vaso") }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
