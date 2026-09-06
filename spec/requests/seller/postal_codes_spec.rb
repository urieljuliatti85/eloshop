require "rails_helper"

RSpec.describe "Seller postal code lookup", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:address) { PostalCodeLookup::Address.new(street: "Rua das Flores", neighborhood: "Centro", city: "Florianópolis", state: "SC") }

  before { sign_in_as(user) }

  it "returns the address as JSON when the CEP is found" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).with("88010-000").and_return(address)

    get seller_atelier_postal_code_path(cep: "88010-000")

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to eq("street" => "Rua das Flores", "neighborhood" => "Centro", "city" => "Florianópolis", "state" => "SC")
  end

  it "returns 404 when the CEP is not found" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return(nil)

    get seller_atelier_postal_code_path(cep: "00000-000")

    expect(response).to have_http_status(:not_found)
  end

  it "requires a signed-in seller" do
    sign_out

    get seller_atelier_postal_code_path(cep: "88010-000")

    expect(response).to redirect_to(seller_login_path)
  end
end
