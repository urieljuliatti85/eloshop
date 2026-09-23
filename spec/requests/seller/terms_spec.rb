require "rails_helper"

RSpec.describe "Seller commercial terms", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Termos", owner_full_name: "Proprietário Teste", cpf: "13777797855", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "termos@example.com", password: "password123", role: :seller, seller: seller) }

  it "shows the current terms publicly" do
    get seller_terms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(SellerTerms.version)
    expect(response.body).to include("chargebacks")
  end

  it "shows the acceptance form to a signed-in seller" do
    sign_in_without_terms(user)

    get seller_terms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Li e aceito os termos comerciais")
    expect(response.body).to include('name="terms_accepted"')
  end

  it "blocks the seller panel until the current version is accepted" do
    sign_in_without_terms(user)

    get seller_root_path

    expect(response).to redirect_to(seller_terms_path)
  end

  it "records the version, text, timestamp and request evidence" do
    sign_in_without_terms(user)

    post seller_terms_path, params: { terms_accepted: "1" }

    acceptance = SellerTermsAcceptance.find_by!(user: user)
    expect(response).to redirect_to(seller_root_path)
    expect(acceptance.terms_version).to eq(SellerTerms.version)
    expect(acceptance.terms_text).to eq(SellerTerms.text)
    expect(acceptance.terms_digest).to eq(Digest::SHA256.hexdigest(SellerTerms.text))
    expect(acceptance.accepted_at).to be_present
    expect(acceptance.ip_address).to be_present
  end

  private

  def sign_in_without_terms(user)
    post seller_login_path, params: { email_address: user.email_address, password: "password123" }
  end
end
