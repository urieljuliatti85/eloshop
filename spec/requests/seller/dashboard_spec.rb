require "rails_helper"

RSpec.describe "Seller dashboard", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Horizonte", owner_full_name: "Proprietário Teste", cpf: "11777787262", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "horizonte@example.com", password: "password123", role: :seller, seller: seller) }
  let(:customer) { Customer.create!(name: "Cliente do Ateliê", email: "cliente-horizonte@example.com", password: "password123") }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: false, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  it "redirects unauthenticated visitors to login" do
    get seller_root_path

    expect(response).to redirect_to(seller_login_path)
  end

  it "shows the seller operation without exposing another seller data" do
    sign_in_as(user)
    own_product = Product.create!(seller: seller, name: "Cesto Horizonte", sku: "HORIZONTE-1", price_cents: 8_000, stock_quantity: 2, status: :active)
    other_seller = Seller.create!(name: "Outro Ateliê #{SecureRandom.hex(3)}", owner_full_name: "Proprietário Teste", cpf: "11888898933", status: :approved, approved_at: Time.current)
    Product.create!(seller: other_seller, name: "Produto Alheio", sku: "ALHEIO-1", price_cents: 3_000, stock_quantity: 2, status: :active)
    seller_order = create_seller_order(own_product)

    get seller_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Visão geral", "O que fazer agora")
    expect(response.body).to include("Buscar no seu catálogo")
    expect(response.body).to include("Primeiros passos", seller_getting_started_path)
    expect(response.body).to include("Cesto Horizonte")
    expect(response.body).to include("Pedido ##{seller_order.order_id}")
    expect(response.body).to include("Cliente do Ateliê")
    expect(response.body).not_to include("Produto Alheio")
  end

  it "warns that the Mercado Pago account needs a PIX key" do
    sign_in_as(user)

    get seller_root_path

    setup = Nokogiri::HTML(response.body).at_css("[aria-labelledby='setup-title']")
    expect(setup.text.squish).to include("Chave PIX no Mercado Pago", "o PIX dos seus clientes é recusado", "Já cadastrei minha chave PIX")
    expect(setup.css("a").map { |link| link["href"] }).to include(seller_pix_key_guide_path)
    # No painel inicial a etapa é uma linha: os passos ficam na página do guia.
    expect(response.body).not_to include("Gerenciar chaves Pix")
  end

  it "lists paid orders waiting to be prepared, not orders still awaiting payment" do
    product = Product.create!(seller: seller, name: "Cesto Preparo", sku: "PREPARO-1", price_cents: 8_000, stock_quantity: 3, status: :active)
    paid = create_seller_order(product)
    paid.update!(status: :confirmed)
    paid.create_shipment!(carrier: "EloShop", service: "Entrega", shipping_cents: 1_000, estimated_days: 5)
    create_seller_order(product)
    sign_in_as(user)

    get seller_root_path

    todo = Nokogiri::HTML(response.body).at_css("[aria-labelledby='todo-title']").text.squish
    expect(todo).to include("1 pedido pago para preparar e enviar", "1 pedido aguardando o pagamento do cliente")
  end

  it "opens with the page title, the tour invitation and a single setup block before the work summary" do
    sign_in_as(user)

    get seller_root_path

    doc = Nokogiri::HTML(response.body)
    boxes = doc.at_css(".seller-content > div").element_children
    expect(boxes.first.at_css("h1").text).to eq("Visão geral")
    expect(boxes[1]["aria-labelledby"]).to eq("tour-call-title")
    expect(boxes[2]["aria-labelledby"]).to eq("setup-title")
    expect(boxes[3]["aria-labelledby"]).to eq("todo-title")
  end

  it "keeps the tour invitation at the top after the tour was completed" do
    seller.update!(tour_completed_at: Time.current)
    sign_in_as(user)

    get seller_root_path

    boxes = Nokogiri::HTML(response.body).at_css(".seller-content > div").element_children
    expect(boxes[1]["aria-labelledby"]).to eq("tour-call-title")
    expect(boxes[1].text).to include("Refazer o tour")
  end

  it "puts the work summary before the setup block once the seller has orders" do
    product = Product.create!(seller: seller, name: "Cesto Ordem", sku: "ORDEM-1", price_cents: 8_000, stock_quantity: 3, status: :active)
    create_seller_order(product)
    sign_in_as(user)

    get seller_root_path

    labels = Nokogiri::HTML(response.body).css(".seller-content > div > section").map { |node| node["aria-labelledby"] }
    expect(labels.index("todo-title")).to be < labels.index("setup-title")
  end

  it "hides the PIX key warning once the seller confirmed the key" do
    seller.update_column(:pix_key_confirmed_at, Time.current)
    sign_in_as(user)

    get seller_root_path

    expect(response.body).not_to include("precisa ter uma chave PIX cadastrada")
  end

  describe "Mercado Pago box" do
    before { sign_in_as(user) }

    def box_texts
      Nokogiri::HTML(response.body).css(".seller-content > div > section").map { |node| node.text.squish }
    end

    def connect_account!
      seller.update!(
        mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
        mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
        mercado_pago_live_mode: true, mercado_pago_test_account: false, mercado_pago_public_key: "APP_USR-chave-publica"
      )
    end

    it "shows the connect options while the seller has never connected" do
      allow(oauth).to receive(:configured?).and_return(true)

      get seller_root_path

      box = box_texts.find { |text| text.include?("Conta Vendedor no Mercado Pago") }
      expect(box).to include("Já tenho conta: conectar")
      expect(Nokogiri::HTML(response.body).css("a").map { |node| node["href"] }).to include(seller_mercado_pago_connect_path)
    end

    it "shows the connect options again after the seller is disconnected" do
      connect_account!
      seller.disconnect_mercado_pago!
      allow(oauth).to receive(:configured?).and_return(true)

      get seller_root_path

      expect(box_texts.join(" ")).to include("Conta Vendedor no Mercado Pago")
      expect(Nokogiri::HTML(response.body).css("a").map { |node| node["href"] }).to include(seller_mercado_pago_connect_path)
    end

    it "removes the box from the dashboard while the account is connected (Reconectar/Desconectar live in the guide)" do
      connect_account!
      allow(oauth).to receive(:configured?).and_return(true)

      get seller_root_path

      expect(box_texts.join(" ")).not_to include("Recebimentos e verificação")
      expect(response.body).not_to include("Desconectar")
    end

    it "shows no setup box at all when the five steps are done and the account is accepted" do
      connect_account!
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
        pix_key_confirmed_at: Time.current
      )
      seller.products.create!(name: "Primeira peça", sku: "PRONTO-DASH", price_cents: 5_000, stock_quantity: 1)

      get seller_root_path

      expect(response).to have_http_status(:ok)
      expect(box_texts.join(" ")).not_to include("Recebimentos e verificação", "Para começar a vender", "Passo obrigatório", "Cadastro em análise")
      expect(response.body).to include("O que fazer agora")
    end
  end

  describe "'Ver a loja' link" do
    before { sign_in_as(user) }

    def store_links
      doc = Nokogiri::HTML(response.body)
      doc.css("a").select { |node| node.text.squish == "Ver a loja" }.map { |node| node["href"] }
    end

    it "points to the seller's own storefront, in the header and in the mobile menu" do
      get seller_root_path

      expect(store_links).to eq([ seller_path(seller), seller_path(seller) ])
      expect(seller_path(seller)).to eq("/artesaos/#{seller.slug}")
    end

    it "falls back to the general store while the seller has no public page (pending)" do
      seller.update!(status: :pending, approved_at: nil)

      get seller_root_path

      expect(store_links).to eq([ products_path, products_path ])
    end

    it "falls back to the general store when the seller is hidden" do
      seller.hide!

      get seller_root_path

      expect(store_links).to eq([ products_path, products_path ])
    end
  end

  describe "getting started box" do
    before { sign_in_as(user) }

    it "lists only the pending steps, in the Primeiros passos order, with one primary action" do
      seller.update!(status: :pending, approved_at: nil)

      get seller_root_path

      setup = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='setup-title']")
      steps = setup.css("li h3").map { |title| title.text.squish }
      expect(steps.map { |title| title.sub(" Obrigatório", "") }).to eq([ "Endereço do ateliê", "Conta Vendedor no Mercado Pago", "Chave PIX no Mercado Pago", "Primeira peça", "Aprovação da EloShop" ])
      expect(setup.css(".seller-button--primary").size).to eq(1)
    end

    it "tells the seller what is left and links to the Primeiros passos page" do
      get seller_root_path

      doc = Nokogiri::HTML(response.body)
      box = doc.at_css("section[aria-labelledby='setup-title']")
      expect(box).to be_present
      expect(box.text.squish).to include("Para começar a vender")
      # A fixture do vendedor já nasce aprovado: só a etapa de aprovação está pronta.
      expect(box.text.squish).to include("1 de 5 etapas concluídas")
      link = box.css("a").find { |node| node.text.squish == "Ver primeiros passos" }
      expect(link["href"]).to eq(seller_getting_started_path)
    end

    it "counts the steps the same way the Primeiros passos page does" do
      seller.products.create!(name: "Primeira peça", sku: "PRIMEIRA-DASH", price_cents: 5_000, stock_quantity: 1)

      get seller_root_path
      dashboard_count = response.body[/(\d) de 5 etapas concluídas/, 1]

      get seller_getting_started_path
      page_count = response.body[/(\d) de 5 etapas concluídas/, 1]

      expect(dashboard_count).to eq("2")
      expect(dashboard_count).to eq(page_count)
    end

    it "keeps a connected but not accepted account as a step to fix" do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
        mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
        mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
        mercado_pago_live_mode: false, mercado_pago_test_account: true, pix_key_confirmed_at: Time.current
      )
      seller.products.create!(name: "Primeira peça", sku: "PRIMEIRA-NAO-ACEITA", price_cents: 5_000, stock_quantity: 1)

      get seller_root_path

      setup = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='setup-title']")
      expect(setup.text.squish).to include("Conta do Mercado Pago não aceita", "Ver como corrigir")
    end

    it "disappears once the five steps are done" do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
        mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
        mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
        mercado_pago_live_mode: true, mercado_pago_test_account: false,
        pix_key_confirmed_at: Time.current
      )
      seller.products.create!(name: "Primeira peça", sku: "PRIMEIRA-DASH2", price_cents: 5_000, stock_quantity: 1)

      get seller_root_path

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("section[aria-labelledby='setup-title']")).to be_nil
    end
  end

  private

  def create_seller_order(product)
    order = Order.create!(
      customer: customer,
      subtotal_cents: product.price_cents,
      shipping_cents: 1_000,
      discount_cents: 0,
      total_cents: product.price_cents + 1_000,
      shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" },
      idempotency_key: SecureRandom.hex(12)
    )
    platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: order.subtotal_cents, discount_cents: 0)
    order.seller_orders.create!(
      seller: seller,
      subtotal_cents: order.subtotal_cents,
      discount_cents: 0,
      shipping_cents: order.shipping_cents,
      total_cents: order.total_cents,
      platform_fee_cents: platform_fee,
      seller_amount_cents: order.total_cents - platform_fee
    )
  end
end
