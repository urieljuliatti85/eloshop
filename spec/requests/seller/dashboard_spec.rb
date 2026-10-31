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
    seller.update!(
      origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
      origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
      mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
      mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: true, mercado_pago_test_account: false
    )
    sign_in_as(user)

    get seller_root_path

    setup = Nokogiri::HTML(response.body).at_css("[aria-labelledby='setup-title']")
    expect(setup.text.squish).to include("Cadastre uma chave PIX no Mercado Pago", "o pagamento por PIX dos seus clientes é recusado", "Já cadastrei minha chave PIX")
    expect(setup.css("a").map { |link| link["href"] }).to include(seller_pix_key_guide_path)
    # A confirmação recarrega o /painel inteiro, para o selo "Pendente" do menu sair também.
    confirmation = setup.css("form").find { |form| form["action"] == seller_pix_key_confirmation_path }
    expect(confirmation["data-turbo-frame"]).to eq("_top")
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

  def complete_setup!(**attributes)
    seller.update!(
      origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
      origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
      mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "access-token-cifrado",
      mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado", mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: true, mercado_pago_test_account: false,
      pix_key_confirmed_at: Time.current, **attributes
    )
    seller.products.create!(name: "Primeira peça", sku: "PRONTO-#{SecureRandom.hex(3)}", price_cents: 5_000, stock_quantity: 1)
  end

  it "opens with the page title and the Primeiros passos block before the work summary while setup is pending" do
    sign_in_as(user)

    get seller_root_path

    doc = Nokogiri::HTML(response.body)
    boxes = doc.at_css(".seller-content > div").element_children
    expect(boxes.first.at_css("h1").text).to eq("Visão geral")
    expect(boxes.first.css("a").map { |node| node["href"] }).not_to include(new_seller_product_path)
    expect(boxes[1]["aria-label"]).to eq("Nesta página")
    expect(boxes[2].name).to eq("turbo-frame")
    expect(boxes[2]["id"]).to eq("primeiros-passos")
    expect(boxes[2].at_css("section")["aria-labelledby"]).to eq("setup-title")
    expect(boxes[3]["aria-labelledby"]).to eq("todo-title")
    # O tour é a bolinha flutuante, não um bloco da página.
    expect(boxes.last.at_css("button[data-action='tour#start']").text.squish).to eq("Faça o tour")
  end

  describe "'Nesta página' menu" do
    def menu_links(doc)
      doc.css("nav[aria-label='Nesta página'] a").map { |node| [ node.text.squish, node["href"] ] }
    end

    it "jumps to each area of the dashboard, every anchor pointing to an element on the page" do
      sign_in_as(user)

      get seller_root_path

      doc = Nokogiri::HTML(response.body)
      links = menu_links(doc)
      expect(links.map(&:first)).to eq([ "Primeiros passos", "O que fazer agora", "Seus números", "Produtos recentes", "Últimos pedidos" ])
      links.each { |_, href| expect(doc.at_css(href)).to be_present, "#{href} não existe na página" }
    end

    it "has a mobile-only way back to the menu, hidden until the menu leaves the screen" do
      sign_in_as(user)

      get seller_root_path

      doc = Nokogiri::HTML(response.body)
      back = doc.at_css("a[data-back-to-menu-target='button']")
      expect(back["href"]).to eq("#nesta-pagina")
      expect(doc.at_css(back["href"])["aria-label"]).to eq("Nesta página")
      expect(back.key?("hidden")).to be(true)
      expect(back["class"].split).to include("sm:hidden")
    end

    it "leaves Primeiros passos out once setup is done" do
      complete_setup!
      sign_in_as(user)

      get seller_root_path

      expect(menu_links(Nokogiri::HTML(response.body)).map(&:first)).to eq([ "O que fazer agora", "Seus números", "Produtos recentes", "Últimos pedidos" ])
    end
  end

  it "opens with the work summary once setup is done" do
    complete_setup!
    sign_in_as(user)

    get seller_root_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("turbo-frame#primeiros-passos section")).to be_nil
    labels = doc.css(".seller-content > div > section").map { |node| node["aria-labelledby"] }
    expect(labels.first).to eq("todo-title")
  end

  it "keeps the Primeiros passos above the work summary even when the seller has orders" do
    product = Product.create!(seller: seller, name: "Cesto Ordem", sku: "ORDEM-1", price_cents: 8_000, stock_quantity: 3, status: :active)
    create_seller_order(product)
    sign_in_as(user)

    get seller_root_path

    body = response.body
    expect(body.index("setup-title")).to be < body.index("todo-title")
  end

  it "hides the PIX key warning once the seller confirmed the key" do
    seller.update_column(:pix_key_confirmed_at, Time.current)
    sign_in_as(user)

    get seller_root_path

    expect(response.body).not_to include("precisa ter uma chave PIX cadastrada")
  end

  describe "Mercado Pago box" do
    # Com o endereço feito, a conta do Mercado Pago é a etapa atual do bloco.
    before do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP"
      )
      sign_in_as(user)
    end

    def box_texts
      Nokogiri::HTML(response.body).css(".seller-content section").map { |node| node.text.squish }
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

      box = box_texts.find { |text| text.include?("Conecte sua conta do Mercado Pago") }
      expect(box).to include("Conectar Mercado Pago")
      expect(Nokogiri::HTML(response.body).css("a").map { |node| node["href"] }).to include(seller_mercado_pago_connect_path)
    end

    it "shows the connect options again after the seller is disconnected" do
      connect_account!
      seller.disconnect_mercado_pago!
      allow(oauth).to receive(:configured?).and_return(true)

      get seller_root_path

      expect(box_texts.join(" ")).to include("Conecte sua conta do Mercado Pago")
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
      expect(box_texts.join(" ")).not_to include("Recebimentos e verificação", "Primeiros passos", "Passo obrigatório", "Cadastro em análise")
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

    def setup_block
      Nokogiri::HTML(response.body).at_css("section[aria-labelledby='setup-title']")
    end

    it "shows all five steps in the strip and opens the first pending one with the address form" do
      seller.update!(status: :pending, approved_at: nil)

      get seller_root_path

      strip = setup_block.css("ol[aria-label='Etapas para preparar o ateliê'] li")
      expect(strip.size).to eq(5)
      expect(strip.first.at_css("a")["aria-current"]).to eq("step")
      expect(setup_block.at_css("#current-step-title").text.squish).to eq("Preencha o endereço do ateliê")
      expect(setup_block.text.squish).to include("Agora · etapa 1 de 5")
      form = setup_block.at_css("form[action='#{seller_origin_address_path}']")
      expect(form).to be_present
      expect(form.at_css("input[name='seller[origin_zip_code]']")).to be_present
      expect(setup_block.css(".seller-button--primary").map { |node| node["value"] || node.text.squish }).to eq([ "Salvar e continuar" ])
    end

    it "opens the next pending step, keeping the finished ones in the strip" do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP"
      )

      get seller_root_path

      strip = setup_block.css("ol[aria-label='Etapas para preparar o ateliê'] li")
      expect(strip.first.text.squish).to include("(feita)")
      expect(strip[1].at_css("a")["aria-current"]).to eq("step")
      expect(setup_block.at_css("#current-step-title").text.squish).to start_with("Conecte sua conta do Mercado Pago")
    end

    it "keeps the strip on the /painel: each step opens inside the same block" do
      get seller_root_path

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame#primeiros-passos")
      expect(frame["data-turbo-action"]).to eq("advance")
      hrefs = frame.css("ol[aria-label='Etapas para preparar o ateliê'] a").map { |node| node["href"] }
      expect(hrefs).to eq(%w[endereco mercado-pago chave-pix primeira-peca aprovacao].map { |slug| seller_root_path(etapa: slug) })
      expect(frame.css("a").map { |node| node["href"] }).not_to include(seller_getting_started_path)
    end

    it "opens the step chosen in the URL, even a finished one, with a way to the next pending" do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP"
      )

      get seller_root_path(etapa: "endereco")

      expect(setup_block.text.squish).to include("Feito · etapa 1 de 5")
      expect(setup_block.at_css("input[type='submit']")["value"]).to eq("Salvar endereço")
      next_link = setup_block.css("a").find { |node| node.text.squish == "Próxima etapa: Conta do Mercado Pago" }
      expect(next_link["href"]).to eq(seller_root_path(etapa: "mercado-pago"))
    end

    it "ignores an unknown step in the URL and opens the first pending one" do
      get seller_root_path(etapa: "qualquer-coisa")

      expect(setup_block.at_css("#current-step-title").text.squish).to eq("Preencha o endereço do ateliê")
    end

    it "sends the links that leave the panel out of the block frame" do
      seller.update!(
        origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP"
      )

      get seller_root_path(etapa: "primeira-peca")

      new_product = setup_block.css("a").find { |node| node["href"] == new_seller_product_path }
      expect(new_product["data-turbo-frame"]).to eq("_top")
    end

    it "tells the seller what is left" do
      get seller_root_path

      expect(setup_block).to be_present
      expect(setup_block.text.squish).to include("Primeiros passos")
      # A fixture do vendedor já nasce aprovado: só a etapa de aprovação está pronta.
      expect(setup_block.text.squish).to include("1 de 5 etapas concluídas")
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
