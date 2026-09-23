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

  it "explains every setup step using the platform fee configured by the domain" do
    sign_in_as(user)

    get seller_getting_started_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("0 de 4 etapas concluídas")
    expect(response.body).to include(
      "Preencha o endereço do ateliê",
      "Conecte sua conta do Mercado Pago",
      "Cadastre seu primeiro produto",
      "Entenda como você recebe",
      "15%"
    )
    expect(response.body).to include(edit_seller_atelier_path, seller_mercado_pago_connect_path, new_seller_product_path)
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
      mercado_pago_connected_at: Time.current
    )
    seller.products.create!(name: "Primeira peça", sku: "PRIMEIRA-1", price_cents: 5_000, stock_quantity: 1)
    sign_in_as(user)

    get seller_getting_started_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("4 de 4 etapas concluídas")
    expect(response.body.scan("Concluído").size).to eq(4)
    expect(response.body).to include("Revisar endereço", "Ver conexão", "Gerenciar produtos", "Acompanhar pedidos")
  end
end
