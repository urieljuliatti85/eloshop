require "rails_helper"

RSpec.describe "Seller origin address (Primeiros passos no painel)", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Origem", owner_full_name: "Proprietário Teste", cpf: "11777787262") }
  let(:user) { User.create!(email_address: "origem@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }
  let(:address) do
    { origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000", origin_complement: "Sala 2",
      origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP" }
  end

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  it "redirects unauthenticated visitors to login" do
    patch seller_origin_address_path, params: { seller: address }

    expect(response).to redirect_to(seller_login_path)
    expect(seller.reload.origin_street).to be_nil
  end

  it "saves the address and goes back to the /painel, which opens the next pending step" do
    sign_in_as(user)

    patch seller_origin_address_path, params: { seller: address }

    expect(response).to redirect_to(seller_root_path)
    expect(response).to have_http_status(:see_other)
    expect(seller.reload).to be_origin_address_complete
    expect(seller.origin_complement).to eq("Sala 2")

    follow_redirect!
    title = Nokogiri::HTML(response.body).at_css("#current-step-title").text.squish
    expect(title).to start_with("Conecte sua conta do Mercado Pago")
  end

  it "only changes the address, never other seller data sent along" do
    sign_in_as(user)

    patch seller_origin_address_path, params: { seller: address.merge(name: "Outro Nome", status: "approved") }

    expect(seller.reload.name).to eq("Ateliê Origem")
    expect(seller).to be_pending
  end

  it "re-renders the block in the same frame when the address is incomplete" do
    sign_in_as(user)

    patch seller_origin_address_path, params: { seller: address.merge(origin_city: "") }

    expect(response).to have_http_status(:unprocessable_entity)
    doc = Nokogiri::HTML(response.body)
    frame = doc.at_css("turbo-frame#primeiros-passos")
    expect(frame.at_css("#current-step-title").text.squish).to eq("Preencha o endereço do ateliê")
    expect(frame.at_css("[role='alert']").text).to include("Cidade")
    expect(frame.at_css("input[name='seller[origin_street]']")["value"]).to eq("Avenida Paulista")
    expect(seller.reload.origin_street).to be_nil
  end

  it "does not close the step with everything blank" do
    sign_in_as(user)

    patch seller_origin_address_path, params: { seller: address.transform_values { "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Nokogiri::HTML(response.body).at_css("[role='alert']").text).to include("Preencha o endereço completo.")
    expect(seller.reload).not_to be_origin_address_complete
  end
end
