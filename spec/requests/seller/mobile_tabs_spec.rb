require "rails_helper"

RSpec.describe "Seller mobile tabs", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Abas", owner_full_name: "Proprietário Teste", cpf: "11777787262") }
  let(:user) { User.create!(email_address: "abas@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }
  let(:address) do
    { origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
      origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP" }
  end

  before do
    allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth)
    sign_in_as(user)
  end

  def tabs
    Nokogiri::HTML(response.body).at_css("nav[aria-label='Primeiros passos']")
  end

  def work_tabs
    Nokogiri::HTML(response.body).at_css("nav[aria-label='Atalhos do ateliê']")
  end

  def labels(nav)
    nav.css("a").map { |link| link.text.squish.sub(/ \(.*\)\z/, "") }
  end

  def complete_setup!
    seller.update!(
      **address, status: :approved, approved_at: Time.current,
      mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
      mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: true, mercado_pago_test_account: false, pix_key_confirmed_at: Time.current
    )
    seller.products.create!(name: "Primeira peça", sku: "ABAS-1", price_cents: 5_000, stock_quantity: 1)
    connect_superfrete!(seller)
  end

  it "shows the five seller steps and the start, only on mobile, while setup is pending" do
    get seller_root_path

    expect(tabs["class"].split).to include("sm:hidden")
    links = tabs.css("a")
    expect(labels(tabs)).to eq([ "Início", "Endereço", "Mercado Pago", "PIX", "Frete", "Peça" ])
    expect(links.map { |link| link["href"] }).to eq([
      seller_root_path,
      *%w[endereco mercado-pago chave-pix superfrete primeira-peca].map { |slug| seller_root_path(etapa: slug, anchor: "primeiros-passos") }
    ])
    expect(tabs.at_css("ul")["class"].split).to include("grid-cols-6")
  end

  it "marks the page the seller is on, the finished steps and the next one" do
    seller.update!(**address)

    get seller_root_path

    links = tabs.css("a")
    expect(links.first["aria-current"]).to eq("page")
    expect(links[1].text.squish).to include("Endereço", "(feita)")
    expect(links[2].text.squish).to include("Mercado Pago", "(próxima etapa)")
    expect(links[3].text.squish).not_to include("(feita)", "(próxima etapa)")
  end

  it "highlights the step of the page outside the dashboard" do
    get seller_atelier_path

    current = tabs.css("a").find { |link| link["aria-current"] == "page" }
    expect(current.text.squish).to start_with("Endereço")
  end

  it "makes room for the tabs on mobile" do
    get seller_root_path

    expect(Nokogiri::HTML(response.body).at_css("body")["class"]).to include("max-sm:[--seller-tabs-height:4rem]")
  end

  it "is not shown in the theme editor, which has its own bottom bar" do
    get edit_seller_theme_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("nav[data-mobile-tabs]")).to be_nil
    expect(Nokogiri::HTML(response.body).at_css("body")["class"]).not_to include("--seller-tabs-height")
  end

  describe "once setup is done" do
    before { complete_setup! }

    it "orders the day's work as it happens: orders, new piece, catalog, shipping and messages" do
      get seller_root_path

      expect(tabs).to be_nil
      expect(work_tabs["class"].split).to include("sm:hidden")
      expect(labels(work_tabs)).to eq([ "Início", "Pedidos", "Nova peça", "Produtos", "Frete", "Mensagens" ])
      expect(work_tabs.css("a").map { |link| link["href"] }).to eq([
        seller_root_path, seller_orders_path, new_seller_product_path, seller_products_path, seller_shipping_settings_path, seller_messages_path
      ])
      expect(work_tabs.at_css("ul")["class"].split).to include("grid-cols-6")
      expect(work_tabs.css("a").first["aria-current"]).to eq("page")
    end

    it "counts the paid orders waiting to be prepared on the Pedidos tab" do
      customer = Customer.create!(name: "Cliente Abas", email: "cliente-abas@example.com", password: "password123")
      order = Order.create!(customer: customer, subtotal_cents: 5_000, shipping_cents: 1_000, discount_cents: 0, total_cents: 6_000,
        shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" }, idempotency_key: SecureRandom.hex(12))
      platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: 5_000, discount_cents: 0)
      seller_order = order.seller_orders.create!(seller: seller, subtotal_cents: 5_000, discount_cents: 0, shipping_cents: 1_000,
        total_cents: 6_000, platform_fee_cents: platform_fee, seller_amount_cents: 6_000 - platform_fee)
      seller_order.update!(status: :confirmed)
      seller_order.create_shipment!(carrier: "EloShop", service: "Entrega", shipping_cents: 1_000, estimated_days: 5)

      get seller_products_path

      orders_tab = work_tabs.css("a").find { |link| link["href"] == seller_orders_path }
      expect(orders_tab.text.squish).to include("Pedidos", "(1 para preparar e enviar)")
      products_tab = work_tabs.css("a").find { |link| link["aria-current"] == "page" }
      expect(products_tab.text.squish).to eq("Produtos")
    end

    it "marks Nova peça, not Produtos, on the new product form" do
      get new_seller_product_path

      expect(work_tabs.css("a").find { |link| link["aria-current"] == "page" }.text.squish).to eq("Nova peça")
    end
  end
end
