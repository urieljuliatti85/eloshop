require "rails_helper"

RSpec.describe "Seller Mercado Pago guide", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Guia", owner_full_name: "Proprietário Teste", cpf: "12000010601") }
  let(:user) { User.create!(email_address: "guia@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  def connect_seller!
    seller.update!(
      mercado_pago_user_id: "123456",
      mercado_pago_access_token_ciphertext: "x",
      mercado_pago_refresh_token_ciphertext: "y",
      mercado_pago_connected_at: Time.current
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

    it "shows the connected state instead of the connect button" do
      connect_seller!
      sign_in_as(user)

      get seller_mercado_pago_guide_path

      expect(response.body).to include("Conta conectada")
      expect(response.body).not_to include(seller_mercado_pago_connect_path)
    end
  end

  describe "navigation and dashboard banner" do
    it "flags the step as mandatory until the account is connected" do
      sign_in_as(user)

      get seller_root_path

      expect(response.body).to include("Conta Vendedor no Mercado Pago", "Obrigatório", "Passo obrigatório")
      expect(response.body).to include(seller_mercado_pago_guide_path)
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
