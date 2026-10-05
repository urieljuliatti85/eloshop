require "rails_helper"

RSpec.describe "Seller registrations", type: :request do
  describe "GET name availability" do
    it "reports a taken name and suggests a free one" do
      Seller.create!(name: "Ateliê da Ana", owner_full_name: "Ana", cpf: "11144477735")

      get seller_registration_name_availability_path(name: "atelie da ana")

      body = response.parsed_body
      expect(body).to include("available" => false, "suggestion" => "atelie da ana 2")
    end

    it "reports a free name" do
      get seller_registration_name_availability_path(name: "Ateliê Livre")

      expect(response.parsed_body).to include("available" => true, "slug" => "atelie-livre")
    end
  end

  it "tells the seller what to have ready before signing up" do
    get new_seller_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Antes de começar")
    expect(response.body).to include("conta de vendedor do Mercado Pago")
    expect(response.body).to include(how_it_works_path(aba: "vende"))
  end

  it "tells the seller about the launch commission before signing up" do
    get new_seller_registration_path

    expect(response.body).to include("8% nos 3 primeiros meses depois da aprovação")
    expect(response.body).to include("Não há mensalidade, no momento.")
  end

  it "has a title aimed at artisans who want to sell" do
    get new_seller_registration_path

    expect(response.body).to include("<title>Venda seu artesanato online: cadastre seu ateliê | EloShop</title>")
  end

  it "warns that the atelier URL does not change when the name does" do
    get new_seller_registration_path

    expect(response.body).to include("https://eloshop.shop/artesaos/atelie-da-ana")
    expect(response.body).to include("a URL não será alterada")
  end

  it "creates a pending seller account and signs it in" do
    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê da Serra", owner_full_name: "Maria Serra", cpf: "60000000060" },
        user: { email_address: "serra@example.com", password: "password123", password_confirmation: "password123" },
        terms_accepted: "1"
      }
    end.to change(Seller, :count).by(1).and change(User.seller, :count).by(1)
      .and have_enqueued_job(SendWelcomeSellerJob)

    seller = Seller.find_by!(slug: "atelie-da-serra")
    expect(seller).to be_pending
    expect(SellerTermsAcceptance.exists?(seller: seller, terms_version: SellerTerms.version)).to be(true)
    expect(response).to redirect_to(seller_root_path)
  end

  it "does not persist either record when the account is invalid" do
    seller_count = Seller.count
    user_count = User.count

    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Inválido", owner_full_name: "Dono Inválido", cpf: "70000000078" },
        user: { email_address: "invalido@example.com", password: "short", password_confirmation: "different" }
      }
    end.not_to change(Seller, :count)

    expect(Seller.count).to eq(seller_count)
    expect(User.count).to eq(user_count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "shows a translated error when the email address is already registered" do
    User.create!(email_address: "existing@example.com", password: "password123")

    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Existente", owner_full_name: "Dono Existente", cpf: "80000000086" },
        user: { email_address: "existing@example.com", password: "password123", password_confirmation: "password123" }
      }
    end.not_to change(Seller, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("E-mail já está em uso")
    expect(response.body).not_to include("Translation missing")
  end
end
