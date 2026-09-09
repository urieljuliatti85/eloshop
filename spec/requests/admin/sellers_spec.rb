require "rails_helper"

RSpec.describe "Admin sellers", type: :request do
  let(:admin) { User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:seller) { Seller.create!(name: "Ateliê Pendente") }
  let(:seller_user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }

  it "lets platform admins approve a seller" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_approved
  end

  it "does not approve without a connected Mercado Pago account" do
    sign_in_as(admin)

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_pending
  end

  # `live_mode` sozinho não distingue TESTUSER de conta real — ver o
  # comentário em Seller#mercado_pago_real_account?. Uma conta de sandbox
  # já foi aprovada indevidamente antes dessa checagem existir.
  it "does not approve a Mercado Pago sandbox (TESTUSER) account" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(false)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true))

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_pending
  end

  # O formulário desabilitava por `mercado_pago_live_mode?`, critério que
  # deixou de valer quando a aprovação passou a aceitar conta de teste em
  # sandbox: sem isto o modelo aprovaria e a tela não deixaria nem marcar a
  # caixa do KYC.
  it "enables the approval form for a test account while the app runs in sandbox mode" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(true)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true, live_mode: false))

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    checkbox = Nokogiri::HTML(response.body).at_css("input#kyc_level_6_confirmed")
    expect(checkbox["disabled"]).to be_nil
    expect(Nokogiri::HTML(response.body).at_css("input[type=submit][value='Aprovar artesão']")["disabled"]).to be_nil
  end

  it "keeps the approval form disabled for a test account outside sandbox mode" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(false)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true, live_mode: false))

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("input#kyc_level_6_confirmed")["disabled"]).to eq("disabled")
  end

  it "shows the seller's own connection link when Mercado Pago is not connected yet" do
    sign_in_as(admin)

    get admin_seller_path(seller)

    expect(response.body).to include("Conta ainda não conectada")
    expect(response.body).to include(seller_atelier_url)
  end

  it "does not show the connection link once Mercado Pago is connected" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    get admin_seller_path(seller)

    expect(response.body).not_to include(seller_atelier_url)
  end

  it "keeps the platform panel unavailable to sellers" do
    sign_in_as(seller_user)

    get admin_sellers_path

    expect(response).to redirect_to(new_session_path)
  end

  def mercado_pago_credentials(test_account: false, live_mode: true)
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "admin-spec-seller",
      access_token: "access-token",
      refresh_token: "refresh-token",
      expires_at: 180.days.from_now,
      live_mode: live_mode,
      test_account: test_account,
      public_key: "TEST-public-key"
    )
  end
end
