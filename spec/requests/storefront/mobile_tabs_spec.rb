# frozen_string_literal: true

require "rails_helper"

# Abas inferiores da loja no celular: os quatro destinos do menu principal,
# com a aba da página atual marcada. Na área do cliente quem ocupa o rodapé
# da tela são as abas da conta, então as da loja não aparecem.
RSpec.describe "Storefront mobile tabs", type: :request do
  def tabs
    Nokogiri::HTML(response.body).at_css("nav.storefront-tabs")
  end

  it "lists the main menu destinations, in order, and then the sell menu" do
    get root_path

    links = tabs.css("li > a").map { |a| [ a.text.squish, a["href"] ] }
    expect(links).to eq([
      [ "Início", root_path ],
      [ "Loja", products_path ],
      [ "Ateliês", sellers_path ],
      [ "Como funciona", how_it_works_path ]
    ])
    expect(tabs.at_css("button[aria-controls='sell-sheet']").text.squish).to eq("Venda na EloShop")
    expect(response.body).to include("storefront-tabs-area")
  end

  # ADR 007: a quinta aba abre as portas do ateliê e do distribuidor, as
  # mesmas do menu do topo.
  it "opens the atelier and distributor doors from the sell tab" do
    get root_path

    sheet = tabs.at_css("#sell-sheet")
    expect(sheet["hidden"]).not_to be_nil
    expect(sheet.css("a").map { |a| a["href"] }).to include(
      seller_login_path, new_seller_registration_path, distributor_login_path, new_distributor_registration_path
    )
  end

  it "marks the sell tab on the doors' pages" do
    get distributor_login_path
    expect(tabs.at_css("button.account-tab--active").text.squish).to eq("Venda na EloShop")
    expect(tabs.css("a[aria-current='page']")).to be_empty
  end

  it "turns the sell tab into a shortcut to the panel for a signed-in seller" do
    user = User.find_by!(seller: approved_seller)
    post seller_login_path, params: { email_address: user.email_address, password: "password123" }

    get root_path

    expect(tabs.at_css("#sell-sheet")).to be_nil
    expect(tabs.css("a").map { |a| [ a.text.squish, a["href"] ] }).to include([ "Meu painel", seller_root_path ])
  end

  it "marks only the current page tab" do
    get products_path
    expect(tabs.css("a[aria-current='page']").map { |a| a.text.squish }).to eq([ "Loja" ])

    get how_it_works_path
    expect(tabs.css("a[aria-current='page']").map { |a| a.text.squish }).to eq([ "Como funciona" ])
  end

  it "keeps the destinations in the hamburger menu as well" do
    get root_path

    panel = Nokogiri::HTML(response.body).at_css("[data-mobile-menu-target='panel']")
    expect(panel.css("nav a").map { |a| a.text.squish }).to include("Início", "Loja", "Ateliês", "Como funciona")
  end

  it "is replaced by the account tabs in the customer area" do
    customer = Customer.create!(name: "Ana Abas", email: "ana-abas-#{SecureRandom.hex(3)}@eloshop.test", password: "password123")
    post customer_session_path, params: { email: customer.email, password: "password123" }

    get orders_path

    html = Nokogiri::HTML(response.body)
    expect(html.at_css("nav.account-tabs")).to be_present
    expect(html.at_css("nav.storefront-tabs")).to be_nil
    expect(response.body).not_to include("storefront-tabs-area")
  end
end
