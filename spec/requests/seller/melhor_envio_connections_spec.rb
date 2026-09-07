require "rails_helper"

RSpec.describe "Seller Melhor Envio connection", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Frete") }
  let(:user) { User.create!(email_address: "frete-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MelhorEnvioOauth, configured?: true, sandbox?: false) }

  before do
    sign_in_as(user)
    allow(Marketplace::MelhorEnvioOauth).to receive(:new).and_return(oauth)
  end

  it "shows the connection action on the atelier page when OAuth is configured" do
    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    connect_link = Nokogiri::HTML(response.body).at_css("a[href='#{seller_melhor_envio_connect_path}']")
    expect(connect_link.text).to eq("Conectar Melhor Envio")
    expect(connect_link["data-turbo"]).to eq("false")
  end

  it "warns when the platform has not configured the application yet" do
    allow(oauth).to receive(:configured?).and_return(false)

    get seller_atelier_path

    expect(response.body).to include("aguarda a configuração da aplicação Melhor Envio")
    expect(Nokogiri::HTML(response.body).at_css("a[href='#{seller_melhor_envio_connect_path}']")).to be_nil
  end

  it "starts authorization with an unpredictable state" do
    allow(oauth).to receive(:authorization_url) do |state:|
      "https://melhorenvio.com.br/oauth/authorize?state=#{CGI.escape(state)}"
    end

    get seller_melhor_envio_connect_path

    expect(response).to redirect_to(%r{\Ahttps://melhorenvio\.com\.br/oauth/authorize})
    expect(response.location).to include("state=")
  end

  it "connects the current seller after a valid callback" do
    state = start_authorization
    credentials = Marketplace::MelhorEnvioOauth::Credentials.new(
      access_token: "access-token-secret",
      refresh_token: "refresh-token-secret",
      expires_at: 30.days.from_now
    )
    allow(oauth).to receive(:exchange).with(code: "valid-code").and_return(credentials)

    get seller_melhor_envio_callback_path, params: { code: "valid-code", state: state }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).to be_melhor_envio_connected
    expect(seller.melhor_envio_access_token).to eq("access-token-secret")
  end

  # O `state` é a defesa contra CSRF no retorno do provedor: sem ele, um
  # terceiro poderia forçar a vinculação de uma conta que não é do vendedor.
  it "refuses a callback with a forged state" do
    start_authorization

    get seller_melhor_envio_callback_path, params: { code: "valid-code", state: "forged-state" }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_melhor_envio_connected
  end

  it "refuses a callback without a previous authorization" do
    get seller_melhor_envio_callback_path, params: { code: "valid-code", state: "any-state" }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_melhor_envio_connected
  end

  it "reports a failed exchange without connecting" do
    state = start_authorization
    allow(oauth).to receive(:exchange).and_raise(Marketplace::MelhorEnvioOauth::RequestFailed, "Melhor Envio recusou a vinculação")

    get seller_melhor_envio_callback_path, params: { code: "valid-code", state: state }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_melhor_envio_connected
  end

  it "disconnects the account without touching the seller status" do
    seller.connect_melhor_envio!(
      Marketplace::MelhorEnvioOauth::Credentials.new(
        access_token: "access", refresh_token: "refresh", expires_at: 30.days.from_now
      )
    )
    seller.update!(status: :approved, approved_at: Time.current)

    delete seller_melhor_envio_connection_path

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_melhor_envio_connected
    # Diferente do Mercado Pago: sem conta de frete o vendedor segue vendendo,
    # o checkout só volta para a tabela padrão. Não há razão para suspender.
    expect(seller).to be_approved
  end

  private

  def start_authorization
    allow(oauth).to receive(:authorization_url) do |state:|
      "https://melhorenvio.com.br/oauth/authorize?state=#{CGI.escape(state)}"
    end
    get seller_melhor_envio_connect_path
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end
end
