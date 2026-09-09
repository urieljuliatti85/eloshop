require "rails_helper"

RSpec.describe "Seller Mercado Pago connection", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê OAuth") }
  let(:user) { User.create!(email_address: "oauth-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before do
    sign_in_as(user)
    allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth)
  end

  it "shows the connection action on the atelier page when OAuth is configured" do
    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    connect_link = Nokogiri::HTML(response.body).at_css("a[href='#{seller_mercado_pago_connect_path}']")
    expect(connect_link.text).to eq("Conectar Mercado Pago")
    expect(connect_link["data-turbo"]).to eq("false")
  end

  it "identifies sandbox connections on the atelier page" do
    allow(oauth).to receive(:sandbox?).and_return(true)

    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ambiente de teste")
    expect(response.body).to include("Conectar conta de teste")
  end

  it "starts authorization with an unpredictable state" do
    allow(oauth).to receive(:authorization_url) do |state:, code_challenge:|
      "https://auth.mercadopago.com.br/authorization?state=#{CGI.escape(state)}"
    end

    get seller_mercado_pago_connect_path

    expect(response).to redirect_to(%r{\Ahttps://auth\.mercadopago\.com\.br/authorization})
    expect(response.location).to include("state=")
  end

  it "connects the current seller after a valid callback" do
    state = start_authorization
    credentials = Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "mp-123",
      access_token: "access-token-secret",
      refresh_token: "refresh-token-secret",
      expires_at: 180.days.from_now,
      live_mode: true,
      test_account: false,
      public_key: "TEST-public-key"
    )
    allow(oauth).to receive(:exchange).with(code: "valid-code", code_verifier: an_instance_of(String)).and_return(credentials)

    get seller_mercado_pago_callback_path, params: { code: "valid-code", state: state }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).to be_mercado_pago_connected
    expect(seller.mercado_pago_user_id).to eq("mp-123")
    expect(seller.mercado_pago_access_token_ciphertext).not_to include("access-token-secret")

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Conta conectada em")
    expect(response.body).to include("Ambiente: produção")
  end

  it "rejects a callback with an invalid state without exchanging the code" do
    allow(oauth).to receive(:exchange)
    start_authorization

    get seller_mercado_pago_callback_path, params: { code: "valid-code", state: "tampered" }

    expect(response).to redirect_to(seller_atelier_path)
    expect(oauth).not_to have_received(:exchange)
    expect(seller.reload).not_to be_mercado_pago_connected
  end

  it "does not allow the same Mercado Pago account on two sellers" do
    other_seller = Seller.create!(name: "Outro Ateliê OAuth")
    credentials = Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "mp-duplicated",
      access_token: "other-access",
      refresh_token: "other-refresh",
      expires_at: 180.days.from_now,
      live_mode: true,
      test_account: false,
      public_key: "TEST-public-key"
    )
    other_seller.connect_mercado_pago!(credentials)
    state = start_authorization
    allow(oauth).to receive(:exchange).with(code: "valid-code", code_verifier: an_instance_of(String)).and_return(credentials)

    get seller_mercado_pago_callback_path, params: { code: "valid-code", state: state }

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_mercado_pago_connected
  end

  it "offers reconnecting alongside disconnecting once an account is connected" do
    connect_seller(public_key: nil)

    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    reconnect_link = Nokogiri::HTML(response.body).at_css("a[href='#{seller_mercado_pago_connect_path}']")
    expect(reconnect_link.text).to eq("Reconectar")
    expect(reconnect_link["data-turbo"]).to eq("false")
    expect(response.body).to include("Desconectar")
    # O aviso é a única proteção contra autorizar a conta errada, que zera a
    # aprovação: se ele sair da tela, o botão volta a ser uma armadilha.
    expect(response.body).to include("autorize <strong>a mesma conta</strong>")
    expect(response.body).to include("zera a aprovação do ateliê")
  end

  # Sem a Public Key o cartão não aparece no checkout, e nada na tela dizia
  # isso: o vendedor via a conta conectada e concluía que estava tudo certo.
  it "tells a connected seller without a public key that card payments are unavailable" do
    connect_seller(public_key: nil)

    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cartão de crédito indisponível")
    expect(response.body).to include("Reconecte para liberá-lo")
  end

  it "stops warning about card payments once the public key is stored" do
    connect_seller(public_key: "TEST-public-key")

    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Cartão de crédito indisponível")
  end

  # Sem OAuth configurado não há botão de reconectar, então o aviso mandaria o
  # vendedor a uma ação que ele não tem.
  it "does not warn about card payments when the platform has not configured OAuth" do
    allow(oauth).to receive(:configured?).and_return(false)
    connect_seller(public_key: nil)

    get seller_atelier_path

    expect(response.body).not_to include("Cartão de crédito indisponível")
  end

  it "hides the reconnect action when the platform has not configured OAuth" do
    allow(oauth).to receive(:configured?).and_return(false)
    connect_seller(public_key: nil)

    get seller_atelier_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("a[href='#{seller_mercado_pago_connect_path}']")).to be_nil
  end

  # O botão "Reconectar" aponta para a mesma rota de conectar, então ela tem
  # de aceitar ser chamada com uma conta já vinculada — é justamente o caso de
  # quem precisa gravar a Public Key sem se despublicar.
  it "starts authorization again for a seller that is already connected" do
    connect_seller(public_key: nil)
    seller.update!(status: :approved, approved_at: Time.current)

    state = start_authorization

    expect(state).to be_present
    expect(response).to have_http_status(:redirect)
    expect(seller.reload).to be_approved
  end

  it "disconnects the account and suspends publication" do
    connect_seller
    seller.update!(status: :approved, approved_at: Time.current)

    delete seller_mercado_pago_connection_path

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).to be_pending
    expect(seller).not_to be_mercado_pago_connected
  end

  private

  def connect_seller(public_key: "TEST-public-key")
    seller.connect_mercado_pago!(
      Marketplace::MercadoPagoOauth::Credentials.new(
        user_id: "mp-456", access_token: "access", refresh_token: "refresh", expires_at: 180.days.from_now,
        live_mode: true, test_account: false, public_key: public_key
      )
    )
  end

  def start_authorization
    allow(oauth).to receive(:authorization_url) do |state:, code_challenge:|
      "https://auth.mercadopago.com.br/authorization?state=#{CGI.escape(state)}"
    end
    get seller_mercado_pago_connect_path
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end
end
