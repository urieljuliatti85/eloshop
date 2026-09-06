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

  it "keeps the platform panel unavailable to sellers" do
    sign_in_as(seller_user)

    get admin_sellers_path

    expect(response).to redirect_to(new_session_path)
  end

  def mercado_pago_credentials
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "admin-spec-seller",
      access_token: "access-token",
      refresh_token: "refresh-token",
      expires_at: 180.days.from_now,
      live_mode: true,
      test_account: false
    )
  end
end
