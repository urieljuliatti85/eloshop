require "rails_helper"

RSpec.describe "Seller sessions", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê da Sessão", status: :approved, approved_at: Time.current) }
  let(:seller_user) { User.create!(email_address: "sessao-vendedor@eloshop.test", password: "password123", role: :seller, seller: seller) }
  let(:admin) { User.create!(email_address: "sessao-admin@eloshop.test", password: "password123") }

  describe "GET /painel/entrar" do
    it "renders the login form" do
      get seller_login_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Entrar no Ateliê")
    end
  end

  describe "POST /painel/entrar" do
    it "signs in a seller" do
      post seller_login_path, params: { email_address: seller_user.email_address, password: "password123" }

      expect(response).to redirect_to(seller_root_path)
      expect(response.cookies).to have_key("session_id")
    end

    # Esta porta é do ateliê, não da administração: mesmo com a senha certa,
    # um admin não tem sessão aberta por aqui.
    it "rejects an admin even with a correct password" do
      post seller_login_path, params: { email_address: admin.email_address, password: "password123" }

      expect(response).to redirect_to(seller_login_path)
      expect(response.cookies["session_id"]).to be_nil
      expect(Current.session).to be_nil
    end

    it "rejects invalid credentials" do
      post seller_login_path, params: { email_address: seller_user.email_address, password: "wrong" }

      expect(response).to redirect_to(seller_login_path)
      expect(response.cookies["session_id"]).to be_nil
    end

    it "returns to the page the seller was trying to reach" do
      get seller_atelier_path
      expect(response).to redirect_to(seller_login_path)

      post seller_login_path, params: { email_address: seller_user.email_address, password: "password123" }

      expect(response).to redirect_to(seller_atelier_path)
    end
  end

  describe "DELETE /painel/sair" do
    it "logs out the current seller" do
      post seller_login_path, params: { email_address: seller_user.email_address, password: "password123" }

      delete seller_logout_path

      expect(response).to redirect_to(seller_login_path)
      expect(response.cookies["session_id"]).to be_nil
    end
  end
end
