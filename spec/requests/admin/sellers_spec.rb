require "rails_helper"

RSpec.describe "Admin sellers", type: :request do
  let(:admin) { User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:seller) { Seller.create!(name: "Ateliê Pendente") }
  let(:seller_user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }

  it "lets platform admins approve a seller" do
    sign_in_as(admin)

    patch approve_admin_seller_path(seller)

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_approved
  end

  it "keeps the platform panel unavailable to sellers" do
    sign_in_as(seller_user)

    get admin_sellers_path

    expect(response).to redirect_to(new_session_path)
  end
end
