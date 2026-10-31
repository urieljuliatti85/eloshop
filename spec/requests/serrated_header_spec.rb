require "rails_helper"

# O topo do site inteiro tem a borda de baixo serrilhada (.topo-serrilhado,
# em application.css): loja, painel do artesão e administração.
RSpec.describe "Serrated top bar", type: :request do
  def headers_with_serrated_edge
    Nokogiri::HTML(response.body).css("header.topo-serrilhado")
  end

  it "is on the storefront" do
    get root_path

    expect(headers_with_serrated_edge.size).to eq(1)
  end

  it "is on the seller panel" do
    seller = Seller.create!(name: "Ateliê Serrilhado", owner_full_name: "Proprietário Teste", cpf: "11777787262", status: :approved, approved_at: Time.current)
    user = User.create!(email_address: "serrilhado@example.com", password: "password123", role: :seller, seller: seller)
    allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(instance_double(Marketplace::MercadoPagoOauth, configured?: false, sandbox?: false))
    sign_in_as(user)

    get seller_root_path

    expect(headers_with_serrated_edge.size).to eq(1)
  end

  it "is on both admin top bars, desktop and mobile" do
    sign_in_as(User.create!(email_address: "admin-serrilhado@example.com", password: "password123", role: :admin))

    get admin_root_path

    expect(headers_with_serrated_edge.map { |header| header["class"].split.first }).to contain_exactly("admin-mobile-header", "admin-topbar")
  end
end
