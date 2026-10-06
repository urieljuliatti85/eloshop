require "rails_helper"

RSpec.describe "Seller PIX key guide", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Pix", owner_full_name: "Proprietário Teste", cpf: "12000010601") }
  let(:user) { User.create!(email_address: "pix@example.com", password: "password123", role: :seller, seller: seller) }

  describe "GET /painel/cadastro-chave-pix" do
    it "requires a seller session" do
      get seller_pix_key_guide_path
      expect(response).to redirect_to(seller_login_path)
    end

    it "shows the red tab and the warning until the key is confirmed" do
      sign_in_as(user)

      get seller_pix_key_guide_path
      expect(response.body).to include("Cadastro da Chave Pix", "bg-red-700", "Já cadastrei minha chave PIX")

      seller.update_column(:pix_key_confirmed_at, Time.current)
      get seller_pix_key_guide_path
      expect(response.body).to include("Reativar o aviso")
      expect(response.body).not_to include("precisa ter uma chave PIX cadastrada")
    end

    it "shows one step per tab and falls back to step 1 on invalid values" do
      sign_in_as(user)

      get seller_pix_key_guide_path
      expect(response.body).to include("Passo 1 de 6", "Toque em Pix")

      get seller_pix_key_guide_path(passo: 6)
      expect(response.body).to include("Passo 6 de 6", "Já cadastrei minha chave PIX")
      expect(response.body).not_to include("Próximo passo")

      get seller_pix_key_guide_path(passo: 99)
      expect(response.body).to include("Passo 6 de 6")

      get seller_pix_key_guide_path(passo: "abc")
      expect(response.body).to include("Passo 1 de 6")
    end
  end
end
