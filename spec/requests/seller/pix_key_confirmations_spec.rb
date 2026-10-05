require "rails_helper"

RSpec.describe "Seller PIX key confirmation", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Chave", owner_full_name: "Proprietário Teste", cpf: "11777787262", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "chave@example.com", password: "password123", role: :seller, seller: seller) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê #{SecureRandom.hex(3)}", owner_full_name: "Proprietário Teste", cpf: "11888898933", status: :approved, approved_at: Time.current) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  it "requires a seller session" do
    post seller_pix_key_confirmation_path

    expect(response).to redirect_to(seller_login_path)
    expect(seller.reload.pix_key_confirmed_at).to be_nil
  end

  it "records the declaration for the signed-in seller only, keeping the first date on repeat" do
    sign_in_as(user)

    post seller_pix_key_confirmation_path
    first = seller.reload.pix_key_confirmed_at
    post seller_pix_key_confirmation_path

    expect(response).to redirect_to(seller_getting_started_path)
    expect(first).to be_present
    expect(seller.reload.pix_key_confirmed_at).to eq(first)
    expect(other_seller.reload.pix_key_confirmed_at).to be_nil
  end

  it "ignores a seller_id sent in the request" do
    sign_in_as(user)

    post seller_pix_key_confirmation_path, params: { seller_id: other_seller.id }

    expect(other_seller.reload.pix_key_confirmed_at).to be_nil
    expect(seller.reload.pix_key_confirmed_at).to be_present
  end

  it "lets the seller undo the declaration and completes the step meanwhile" do
    sign_in_as(user)

    post seller_pix_key_confirmation_path
    get seller_getting_started_path
    expect(response.body).to include("Ainda não cadastrei")

    delete seller_pix_key_confirmation_path

    expect(seller.reload.pix_key_confirmed_at).to be_nil
    expect(seller.getting_started_steps[:pix_key]).to be(false)
  end
end
