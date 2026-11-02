# frozen_string_literal: true

require "rails_helper"

# Navegação da área do cliente: lateral no desktop e abas no rodapé do
# celular (Início, Pedidos, Favoritos, Notificações e "Mais" com o resto),
# só nas páginas marcadas com StorefrontController.account_area e só com
# cliente logado. O checkout mora em OrdersController e não herda o menu.
RSpec.describe "Customer account navigation", type: :request do
  let(:customer) { Customer.create!(name: "Ana Souza", email: "ana-menu@eloshop.test", password: "password123") }

  def sign_in(who = customer)
    post customer_session_path, params: { email: who.email, password: "password123" }
  end

  def page_html
    Nokogiri::HTML(response.body)
  end

  def tabs
    page_html.at_css("nav.account-tabs")
  end

  def sidebar
    page_html.at_css("aside.account-sidebar")
  end

  it "shows the sidebar and the bottom tabs on the account page" do
    sign_in

    get account_root_path

    expect(tabs.css("ul > li").map { |item| item.text.squish }).to eq([ "Início", "Pedidos", "Favoritos", "Notificações", "Mais" ])
    expect(tabs.css("#account-tabs-sheet a").map { |link| link.text.squish }).to eq([ "Endereços", "Cadastro" ])
    expect(tabs.at_css("#account-tabs-sheet form[action='#{customer_session_path}']")).to be_present
    expect(sidebar.css("nav a").map { |link| link.text.squish }).to eq([ "Início", "Pedidos", "Favoritos", "Notificações", "Endereços", "Cadastro" ])
    expect(sidebar.at_css("form[action='#{customer_session_path}']")).to be_present
  end

  it "marks the current area in the tabs and the sidebar" do
    sign_in

    get orders_path

    expect(tabs.css("a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Pedidos" ])
    expect(sidebar.css("a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Pedidos" ])
  end

  it "marks the more button and the item inside it for an area in the more menu" do
    sign_in

    get addresses_path

    expect(tabs.at_css("button.account-tab")["class"]).to include("account-tab--active")
    expect(tabs.css("#account-tabs-sheet a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Endereços" ])
  end

  it "counts only the customer's own unread notifications" do
    other = Customer.create!(name: "Beto", email: "beto-menu@eloshop.test", password: "password123")
    2.times { |i| Notification.create!(recipient: customer, kind: :order_shipped, title: "Pedido #{i}", body: "Atualizado.") }
    Notification.create!(recipient: customer, kind: :order_shipped, title: "Lida", body: "Vista.", read_at: Time.current)
    Notification.create!(recipient: other, kind: :order_shipped, title: "Alheia", body: "Não é sua.")
    sign_in

    get account_root_path

    notifications_tab = tabs.at_css("a[href='#{notifications_path}']")
    expect(notifications_tab.at_css(".account-tab-count").text).to eq("2")
    expect(notifications_tab.text).to include("(2 não lidas)")
  end

  it "does not show the account navigation in the checkout" do
    product = Product.create!(seller: approved_seller, name: "Menu no checkout", sku: "MENU-CHECKOUT", price_cents: 1000, stock_quantity: 1, status: :active)
    sign_in
    post cart_items_path, params: { product_id: product.id, quantity: 1 }

    get new_order_path

    expect(response).to have_http_status(:ok)
    expect(tabs).to be_nil
    expect(sidebar).to be_nil
    expect(response.body).not_to include("account-area")
  end

  it "does not show the account navigation outside the account area" do
    sign_in

    get root_path

    expect(tabs).to be_nil
    expect(sidebar).to be_nil
  end
end
