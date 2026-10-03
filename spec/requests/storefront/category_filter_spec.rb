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

    before { get products_path }

    it "lists one entry per top-level category instead of one pill per category" do
      labels = menu.css("a, button").map { |node| node.text.squish }

      expect(labels).to include("Todos", "Casa", "Moda", "Infantil")
      expect(labels).not_to include("Casa > Cozinha")
    end

    it "opens a dropdown only for the categories that have children" do
      dropdown_labels = menu.css("button[data-account-menu-target='button']").map { |node| node.text.squish }

      expect(dropdown_labels).to contain_exactly("Casa", "Moda")
      expect(menu.css("a").map { |node| node["href"] }).to include(products_path(category: "infantil"))
    end

    it "lists 'Ver tudo' and the children inside the dropdown panel" do
      panel = menu.at_css("[data-account-menu-target='panel']")

      expect(panel.has_attribute?("hidden")).to be(true)
      expect(panel.css("a").map { |node| node.text.squish }).to eq([ "Ver tudo em Casa", "Cozinha", "Decoração" ])
      expect(panel.css("a").map { |node| node["href"] }).to include(products_path(category: "cozinha"))
    end

    it "offers the same categories, grouped by parent, in the search dropdown" do
      select = doc.at_css("select#search-category")

      expect(select.at_css("option")["value"]).to eq("")
      group = select.at_css("optgroup[label='Casa']")
      expect(group.css("option").map { |option| option.text.squish }).to eq([ "Todos em Casa", "Cozinha", "Decoração" ])
      expect(select.css("option[value='infantil']")).to be_present
    end

    it "wires the search box as an accessible combobox with a suggestions endpoint" do
      form = doc.at_css("form[data-controller='product-autocomplete']")

      expect(form["data-product-autocomplete-url-value"]).to eq(suggestions_products_path)
      input = form.at_css("input[name='q']")
      expect(input["role"]).to eq("combobox")
      expect(input["aria-controls"]).to eq("search-suggestions")
      expect(form.at_css("ul#search-suggestions[role='listbox']")).to be_present
    end
  end

  describe "GET /produtos with a category" do
    it "highlights the parent when the current category is one of its children" do
      get products_path(category: "cozinha")

      doc = Nokogiri::HTML(response.body)
      casa_button = doc.css("nav[aria-label='Categorias'] button").find { |node| node.text.squish == "Casa" }
      expect(casa_button["class"]).to include("bg-ink")
      expect(doc.at_css("select#search-category option[value='cozinha']")["selected"]).to be_present
    end

    it "does not offer a disabled category or a child of a disabled one" do
      moda.update!(active: false)

      get products_path

      doc = Nokogiri::HTML(response.body)
      menu_labels = doc.css("nav[aria-label='Categorias'] a, nav[aria-label='Categorias'] button").map { |node| node.text.squish }
      expect(menu_labels).not_to include("Moda")
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
