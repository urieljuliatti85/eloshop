require "rails_helper"

RSpec.describe "Seller Mercado Pago guide", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Guia", owner_full_name: "Proprietário Teste", cpf: "12000010601") }
  let(:user) { User.create!(email_address: "guia@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  # `test_account: false` com `live_mode` é o que a aprovação aceita fora do
  # sandbox; sem isso o vendedor tem tokens, mas não uma conta aceita.
  def connect_seller!(live_mode: true, test_account: false)
    seller.update!(
      mercado_pago_user_id: "123456",
      mercado_pago_access_token_ciphertext: "x",
      mercado_pago_refresh_token_ciphertext: "y",
      mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: live_mode,
      mercado_pago_test_account: test_account
    )
  end

  describe "GET /painel/conta-vendedor-mercado-pago" do
    it "redirects unauthenticated visitors to the seller login" do
      get seller_mercado_pago_guide_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "keeps an admin out" do
      sign_in_as(User.create!(email_address: "admin-guia@eloshop.test", password: "password123"))

      get seller_mercado_pago_guide_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "explains the steps, the account type and the platform fee" do
      sign_in_as(user)

      get seller_mercado_pago_guide_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "Conta Vendedor (ou Conta Negócio)",
        "Confirme sua identidade",
        "15%",
        seller_mercado_pago_connect_path
      )
    end

    it "says the Mercado Pago e-mail can differ from the signup e-mail" do
      sign_in_as(user)

      get seller_mercado_pago_guide_path

      expect(response.body).to include("Preciso usar o mesmo e-mail da EloShop no Mercado Pago?")
    end

    it "shows the connected state instead of the connect button" do
      connect_seller!
      sign_in_as(user)

      get seller_mercado_pago_guide_path

      expect(response.body).to include("Conta conectada")
      expect(response.body).not_to include(seller_mercado_pago_connect_path)
    end
  end

  describe "connected account that cannot be approved" do
    # O caso de produção: tokens presentes, mas conta de teste ou de origem
    # desconhecida. Dizer "conectado" aqui deixava a vendedora esperando uma
    # aprovação que o admin não consegue dar.
    [ true, nil ].each do |test_account|
      it "warns instead of showing connected when test_account is #{test_account.inspect}" do
        connect_seller!(test_account: test_account)
        sign_in_as(user)

        get seller_root_path

        expect(response.body).to include("Conta não aceita", "não pode ser aprovada")
        expect(response.body).not_to include("✓ Conectado")
        expect(response.body).to include("Em análise").or include("em análise")
        expect(response.body).not_to include("estiver pending")
      end
    end

    it "explains how to fix it on the guide page" do
      connect_seller!(test_account: true)
      sign_in_as(user)

      get seller_mercado_pago_guide_path

      expect(response.body).to include("A conta conectada não pode ser aprovada", "Conta conectada, mas não aceita")
      expect(response.body).not_to include("✓ Conta conectada")
    end

    it "accepts a test account when the app runs in sandbox mode" do
      allow(oauth).to receive(:sandbox?).and_return(true)
      connect_seller!(live_mode: false, test_account: true)
      sign_in_as(user)

      get seller_root_path

      expect(response.body).to include("✓ Conectado")
      expect(response.body).not_to include("Conta não aceita")
    end
  end

  describe "navigation and dashboard banner" do
    it "flags the step as mandatory until the account is connected" do
      sign_in_as(user)

      get seller_root_path

      expect(response.body).to include("Conta Vendedor no Mercado Pago", "Obrigatório", "Passo obrigatório")
      expect(response.body).to include(seller_mercado_pago_guide_path)
    end

    # O hero ocupa a primeira tela: abaixo dele o passo obrigatório passava
    # despercebido sem rolar a página.
    it "shows the mandatory banner above the hero" do
      sign_in_as(user)

      get seller_root_path

      expect(response.body.index("Passo obrigatório")).to be < response.body.index("Crie, publique e acompanhe cada venda")
    end

    it "keeps every notice above the hero, in reading order" do
      sign_in_as(user)

      get seller_root_path

      body = response.body
      hero = body.index("Crie, publique e acompanhe cada venda")
      order = [ "Passo obrigatório", "Cadastro em análise", "Recebimentos e verificação" ].map { |text| body.index(text) }

      expect(order).to all(be_present)
      expect(order).to eq(order.sort)
      expect(order.last).to be < hero
    end

    it "replaces the warning with a connected label once connected" do
      connect_seller!
      sign_in_as(user)

      get seller_root_path

      expect(response.body).to include("Conectado")
      expect(response.body).not_to include("Passo obrigatório")
      expect(response.body).not_to include("Obrigatório")
    end
  end
end
