require "rails_helper"

RSpec.describe "Seller getting started", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Começo", owner_full_name: "Proprietário Teste", cpf: "12000010601") }
  let(:user) { User.create!(email_address: "comeco@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  it "redirects unauthenticated visitors to the seller login" do
    get seller_getting_started_path

    expect(response).to redirect_to(seller_login_path)
  end

  it "opens the next pending step and lists all five as a notebook index" do
    sign_in_as(user)

    get seller_getting_started_path

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    index = doc.css("ol[aria-label='Etapas para preparar o ateliê'] a")
    expect(index.map { |link| link.text.squish }).to all(be_present)
    expect(index.map { |link| link["href"] }).to eq(%w[endereco mercado-pago chave-pix primeira-peca aprovacao].map { |slug| seller_getting_started_path(etapa: slug) })
    expect(doc.at_css("a[aria-current='step']")["href"]).to eq(seller_getting_started_path(etapa: "endereco"))
    expect(response.body).to include("0 de 5 etapas concluídas", "Preencha o endereço do ateliê", edit_seller_atelier_path)
  end

  it "shows one step per page, each with its own action" do
    sign_in_as(user)

    get seller_getting_started_path(etapa: "mercado-pago")
    expect(response.body).to include("Conecte sua conta do Mercado Pago", seller_mercado_pago_connect_path)

    get seller_getting_started_path(etapa: "chave-pix")
    expect(response.body).to include("Cadastre uma chave PIX no Mercado Pago", "Gerenciar chaves Pix", seller_pix_key_guide_path)
    expect(response.body.scan("Ver o passo a passo com imagens").size).to eq(1)
    expect(response.body).not_to include(seller_mercado_pago_connect_path)

    get seller_getting_started_path(etapa: "primeira-peca")
    expect(response.body).to include("Cadastre seu primeiro produto", new_seller_product_path)

    get seller_getting_started_path(etapa: "aprovacao")
    expect(response.body).to include("Entenda como você recebe", "15%")
  end

  it "does not route an unknown step" do
    sign_in_as(user)

    get "/painel/primeiros-passos/qualquer-coisa"

    expect(response).to have_http_status(:not_found)
  end

  it "offers the next pending step once the open one is done" do
    seller.update!(pix_key_confirmed_at: Time.current)
    sign_in_as(user)

    get seller_getting_started_path(etapa: "chave-pix")

    expect(response.body).to include("Feito", "Ainda não cadastrei")
    expect(response.body).to include("Próxima etapa: Primeira peça", seller_getting_started_path(etapa: "primeira-peca"))
  end

  it "tells a seller who is not approved yet how the launch commission will work" do
    sign_in_as(user)

    get seller_getting_started_path(etapa: "aprovacao")

    expect(response.body).to include("8% nos 3 primeiros meses depois da aprovação do seu ateliê e 15% depois disso")
  end

  it "shows the launch commission with its end date to a recently approved seller" do
    seller.update!(status: :approved, approved_at: Time.zone.local(2026, 10, 3))
    sign_in_as(user)

    travel_to Time.zone.local(2026, 10, 10) do
      get seller_getting_started_path(etapa: "aprovacao")
    end

    expect(response.body).to include("8% (comissão de lançamento, até 03/01/2027; depois, 15%)")
  end

  it "shows only the standard commission after the launch period" do
    seller.update!(status: :approved, approved_at: 4.months.ago)
    sign_in_as(user)

    get seller_getting_started_path(etapa: "aprovacao")

    expect(response.body).not_to include("comissão de lançamento")
    expect(response.body).to include("<strong>15%</strong>")
  end

  it "derives completed steps from the current seller data" do
    seller.update!(
      status: :approved,
      approved_at: Time.current,
      origin_zip_code: "01310100",
      origin_street: "Avenida Paulista",
      origin_number: "1000",
      origin_neighborhood: "Bela Vista",
      origin_city: "São Paulo",
      origin_state: "SP",
      mercado_pago_user_id: "123456",
      mercado_pago_access_token_ciphertext: "access-token-cifrado",
      mercado_pago_refresh_token_ciphertext: "refresh-token-cifrado",
      mercado_pago_connected_at: Time.current,
      pix_key_confirmed_at: Time.current
    )
    seller.products.create!(name: "Primeira peça", sku: "PRIMEIRA-1", price_cents: 5_000, stock_quantity: 1)
    sign_in_as(user)

    get seller_getting_started_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("5 de 5 etapas concluídas", "Ateliê pronto", seller_root_path)
    expect(Nokogiri::HTML(response.body).css(".caderno-indice .caderno-carimbo").size).to eq(5)

    { "endereco" => "Revisar endereço", "mercado-pago" => "Ver conexão", "primeira-peca" => "Gerenciar produtos", "aprovacao" => "Acompanhar pedidos" }.each do |slug, action|
      get seller_getting_started_path(etapa: slug)
      expect(response.body).to include(action)
    end
    get seller_getting_started_path(etapa: "chave-pix")
    expect(response.body).not_to include("Ver o passo a passo com imagens")
  end
end
