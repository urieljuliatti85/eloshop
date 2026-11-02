# frozen_string_literal: true

require "rails_helper"

# Abas inferiores da loja no celular: os quatro destinos do menu principal,
# com a aba da página atual marcada. Na área do cliente quem ocupa o rodapé
# da tela são as abas da conta, então as da loja não aparecem.
RSpec.describe "Storefront mobile tabs", type: :request do
  def tabs
    Nokogiri::HTML(response.body).at_css("nav.storefront-tabs")
  end

  it "lists the main menu destinations, in order" do
    get root_path

    links = tabs.css("a").map { |a| [ a.text.squish, a["href"] ] }
    expect(links).to eq([
      [ "Início", root_path ],
      [ "Loja", products_path ],
      [ "Ateliês", sellers_path ],
      [ "Como funciona", how_it_works_path ]
    ])
    expect(response.body).to include("storefront-tabs-area")
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
