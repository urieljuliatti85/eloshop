require "rails_helper"

RSpec.describe "Seller shipping settings (Frete e entregas)", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Frete", owner_full_name: "Proprietário Teste", cpf: "12111122335") }
  let(:user) { User.create!(email_address: "frete-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::SuperfreteOauth, configured?: true, sandbox?: false) }

  before do
    allow(Marketplace::SuperfreteOauth).to receive(:new).and_return(oauth)
  end

  it "requires a seller login" do
    get seller_shipping_settings_path

    expect(response).to redirect_to(seller_login_path)
  end

  it "teaches how to connect SuperFrete, with the connect button and the required badge" do
    sign_in_as(user)

    get seller_shipping_settings_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("h1").text.squish).to eq("Frete e entregas")
    expect(response.body).to include("Como conectar a SuperFrete", "Obrigatório para vender", "não</strong> traz você de volta", "Jadlog")
    expect(page.at_css("a[href='#{seller_superfrete_connect_path}']")).to be_present
  end

  it "is in the Configuração menu" do
    sign_in_as(user)

    get seller_root_path

    expect(Nokogiri::HTML(response.body).css("a[href='#{seller_shipping_settings_path}']")).to be_present
  end

  # A página mostra só a conexão de quem está logado: nunca a de outro ateliê.
  it "shows only the current seller's connection" do
    other = Seller.create!(name: "Ateliê Vizinho Frete", owner_full_name: "Outra Pessoa", cpf: "52998224725")
    connect_superfrete!(other, email: "vizinho@example.com")
    connect_superfrete!(seller, email: "eu@example.com")
    sign_in_as(user)

    get seller_shipping_settings_path

    expect(response.body).to include("eu@example.com")
    expect(response.body).not_to include("vizinho@example.com")
    expect(Nokogiri::HTML(response.body).at_css("form[action='#{seller_shipping_preference_path}']")).to be_present
  end

  it "asks to reconnect after SuperFrete refused the token" do
    connect_superfrete!(seller)
    seller.mark_superfrete_revoked!
    sign_in_as(user)

    get seller_shipping_settings_path

    expect(response.body).to include("A SuperFrete recusou o acesso")
  end

  it "returns to Frete e entregas after saving the shipping choice there" do
    connect_superfrete!(seller)
    sign_in_as(user)

    patch seller_shipping_preference_path, params: { provider_quotes_preferred: "true" },
      headers: { "HTTP_REFERER" => seller_shipping_settings_url }

    expect(response).to redirect_to(seller_shipping_settings_url)
    expect(seller.reload.provider_quotes_preferred).to be(true)
  end

  context "with remote quotes disabled in the environment" do
    around do |example|
      previous = Rails.configuration.x.shipping.remote_quotes_enabled
      Rails.configuration.x.shipping.remote_quotes_enabled = false
      example.run
    ensure
      Rails.configuration.x.shipping.remote_quotes_enabled = previous
    end

    it "does not demand the connection" do
      sign_in_as(user)

      get seller_shipping_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Como conectar a SuperFrete", "Obrigatório para vender")
    end
  end
end
