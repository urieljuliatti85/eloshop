# frozen_string_literal: true

require "rails_helper"

# Ajustes mobile dos armarinhos (2026-11-08): carrossel de categorias em /armarinhos,
# aba "Armarinhos" na barra inferior das páginas de armarinho e caminho flutuante
# no celular. O comportamento de tela (rolagem, pílula ao sair do breadcrumb) é
# JavaScript e não aparece no HTML; aqui se confere a marcação que o aciona.
RSpec.describe "Armarinhos mobile", type: :request do
  def distributor(name: "Fios #{SecureRandom.hex(3)}")
    Seller.create!(name: name, owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf,
      kind: "distributor", status: :approved, approved_at: Time.current, showcased_at: Time.current,
      issues_invoices: true)
  end

  def supply(seller, name: "Fio #{SecureRandom.hex(3)}")
    seller.products.create!(name: name, price_cents: 2_500, stock_quantity: 100, status: :active,
      sale_unit: "pack", sale_unit_detail: "pacote com 100 g")
  end

  describe "categorias de insumos em /armarinhos" do
    it "shows the categories as a carousel on mobile, with its controls" do
      seller = distributor
      supply(seller).materials << Material.find_or_create_by!(name: "Linho")

      get distributors_path

      html = Nokogiri::HTML(response.body)
      section = html.at_css("section[aria-labelledby='supply-categories-heading']")
      expect(section).to be_present
      expect(section.at_css("[data-controller='carousel']")).to be_present
      expect(section.at_css("[data-carousel-target='track']")).to be_present
      expect(section.at_css("[data-carousel-target='controls']")).to be_present
    end

    it "keeps the category links that filter the supplies" do
      seller = distributor
      material = Material.find_or_create_by!(name: "Linho")
      supply(seller).materials << material

      get distributors_path

      expect(response.body).to include(supplies_path(material: material.slug))
    end
  end

  describe "barra inferior nas páginas de armarinho" do
    it "offers 'Armarinhos' in place of 'Como funciona' on a store page" do
      seller = distributor

      get distributor_store_path(seller.slug)

      tabs = Nokogiri::HTML(response.body).css("nav[aria-label='Navegação da loja'] a").map { |a| [ a.text.squish, a["href"] ] }
      expect(tabs).to include([ "Armarinhos", distributors_path ])
      expect(tabs.map(&:first)).not_to include("Como funciona")
    end

    it "offers 'Armarinhos' on a supply page" do
      seller = distributor
      product = supply(seller)

      get supply_path(seller.slug, product.slug)

      tabs = Nokogiri::HTML(response.body).css("nav[aria-label='Navegação da loja'] a").map { |a| [ a.text.squish, a["href"] ] }
      expect(tabs).to include([ "Armarinhos", distributors_path ])
    end

    it "keeps 'Como funciona' on /insumos, which is not a store page" do
      get supplies_path

      tabs = Nokogiri::HTML(response.body).css("nav[aria-label='Navegação da loja'] a").map(&:text).map(&:squish)
      expect(tabs).to include("Como funciona")
      expect(tabs).not_to include("Armarinhos")
    end
  end

  describe "caminho flutuante no celular" do
    it "renders the floating path on the store page, hidden until the breadcrumb leaves the screen" do
      seller = distributor(name: "Fios da Serra")

      get distributor_store_path(seller.slug)

      html = Nokogiri::HTML(response.body)
      pill = html.at_css("[data-floating-breadcrumb-target='pill']")
      expect(pill).to be_present
      expect(pill.has_attribute?("hidden")).to be(true)
      expect(pill.at_css("nav[aria-label='Caminho flutuante']").text.squish).to include("Armarinhos", "Fios da Serra")
      expect(html.at_css("[data-controller='floating-breadcrumb']")).to be_present
    end

    it "renders the floating path on the supply page with the full chain" do
      seller = distributor(name: "Fios da Serra")
      product = supply(seller, name: "Fio de algodão macio")

      get supply_path(seller.slug, product.slug)

      pill = Nokogiri::HTML(response.body).at_css("nav[aria-label='Caminho flutuante']")
      expect(pill).to be_present
      expect(pill.text.squish).to include("Insumos", "Fios da Serra", "Fio de algodão macio")
    end
  end
end
