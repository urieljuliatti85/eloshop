require "rails_helper"

RSpec.describe "Seller registrations", type: :request do
  it "creates a pending seller account and signs it in" do
    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê da Serra" },
        user: { email_address: "serra@example.com", password: "password123", password_confirmation: "password123" }
      }
    end.to change(Seller, :count).by(1).and change(User.seller, :count).by(1)

    seller = Seller.find_by!(slug: "atelie-da-serra")
    expect(seller).to be_pending
    expect(response).to redirect_to(seller_root_path)
  end

  it "does not persist either record when the account is invalid" do
    seller_count = Seller.count
    user_count = User.count

    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Inválido" },
        user: { email_address: "invalido@example.com", password: "short", password_confirmation: "different" }
      }
    end.not_to change(Seller, :count)

    expect(Seller.count).to eq(seller_count)
    expect(User.count).to eq(user_count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
