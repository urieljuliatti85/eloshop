require "rails_helper"

RSpec.describe "Seller SuperFrete connection", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê SuperFrete", owner_full_name: "Proprietário Teste", cpf: "12111122335") }
  let(:user) { User.create!(email_address: "superfrete-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::SuperfreteOauth, configured?: true, sandbox?: true) }
  let(:account) { Marketplace::SuperfreteOauth::Account.new(id: "sf-1", email: "atelie@example.com") }

  before do
    sign_in_as(user)
    allow(Marketplace::SuperfreteOauth).to receive(:new).and_return(oauth)
  end

  describe "atelier page" do
    it "offers the connection when it is configured" do
      get seller_atelier_path

      expect(Nokogiri::HTML(response.body).at_css("a[href='#{seller_superfrete_connect_path}']")).to be_present
    end

    it "shows the in-development notice instead of the connection when it is not configured" do
      allow(oauth).to receive(:configured?).and_return(false)

      get seller_atelier_path

      expect(response.body).to include("estamos preparando soluções para facilitar as suas entregas")
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{seller_superfrete_connect_path}']")).to be_nil
    end

    it "shows the connected account, the shipping choice and the disconnect action" do
      seller.connect_superfrete!(access_token: "token", account: account, sandbox: true)

      get seller_atelier_path

      page = Nokogiri::HTML(response.body)
      expect(response.body).to include("atelie@example.com")
      expect(page.at_css("form[action='#{seller_superfrete_connection_path}']")).to be_present
      expect(page.at_css("form[action='#{seller_shipping_preference_path}']")).to be_present
    end

    it "asks to reconnect when the connection was made in another SuperFrete environment" do
      allow(Marketplace::SuperfreteOauth).to receive(:sandbox?).and_return(false)
      seller.connect_superfrete!(access_token: "token", account: account, sandbox: true)

      get seller_atelier_path

      expect(response.body).to include("foi feita no ambiente de teste e não serve para cotar o frete agora")
      expect(Nokogiri::HTML(response.body).at_css("form[action='#{seller_superfrete_connection_path}']")).to be_present
    end

    it "does not ask to reconnect when the connection matches the configured environment" do
      allow(Marketplace::SuperfreteOauth).to receive(:sandbox?).and_return(true)
      seller.connect_superfrete!(access_token: "token", account: account, sandbox: true)

      get seller_atelier_path

      expect(response.body).not_to include("não serve para cotar o frete agora")
    end
  end

  it "starts authorization with an unpredictable state, keeping only its digest on the seller" do
    state = start_authorization

    expect(response).to redirect_to(%r{\Ahttps://sandbox\.superfrete\.com/#/auth/authorize\?})
    expect(state.length).to be >= 32
    expect(seller.reload.superfrete_oauth_state_digest).to eq(Digest::SHA256.hexdigest(state))
  end

  # A SuperFrete entrega o `code` com um GET do servidor dela: o retorno chega
  # sem a sessão do ateliê, e é o `state` que diz de quem é a autorização.
  describe "callback, called by SuperFrete's server without the seller session" do
    it "connects the seller who started the authorization and answers 200" do
      state = start_authorization
      expect(oauth).to receive(:exchange).with(code: "valid-code", state: state).and_return("superfrete-token")
      allow(oauth).to receive(:account).with(access_token: "superfrete-token").and_return(account)
      reset!

      get seller_superfrete_callback_path, params: { code: "valid-code", state: state }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("atelie@example.com")
      seller.reload
      expect(seller).to be_superfrete_connected
      expect(seller.superfrete_access_token).to eq("superfrete-token")
      expect([ seller.superfrete_account_id, seller.superfrete_sandbox ]).to eq([ "sf-1", true ])
      expect(seller.superfrete_oauth_state_digest).to be_nil
    end

    it "says so when the seller reconnects with a different account" do
      seller.connect_superfrete!(access_token: "old", account: Marketplace::SuperfreteOauth::Account.new(id: "sf-old", email: nil))
      state = start_authorization
      allow(oauth).to receive(:exchange).and_return("new-token")
      allow(oauth).to receive(:account).and_return(account)
      reset!

      get seller_superfrete_callback_path, params: { code: "valid-code", state: state }

      expect(response.body).to include("trocada")
      expect(seller.reload.superfrete_account_id).to eq("sf-1")
    end

    # Sem a sessão, o `state` é a única defesa: sem ele, qualquer um gravaria
    # um token — e uma carteira — num ateliê alheio.
    it "refuses a forged state without exchanging the code" do
      start_authorization
      expect(oauth).not_to receive(:exchange)
      reset!

      get seller_superfrete_callback_path, params: { code: "valid-code", state: "forged-state" }

      expect(response).to have_http_status(:bad_request)
      expect(seller.reload).not_to be_superfrete_connected
    end

    it "accepts each state only once" do
      state = start_authorization
      allow(oauth).to receive(:exchange).and_return("superfrete-token")
      allow(oauth).to receive(:account).and_return(account)
      reset!

      get seller_superfrete_callback_path, params: { code: "valid-code", state: state }
      expect(response).to have_http_status(:ok)

      get seller_superfrete_callback_path, params: { code: "other-code", state: state }
      expect(response).to have_http_status(:bad_request)
      expect(oauth).to have_received(:exchange).once
    end

    it "refuses an expired state" do
      state = start_authorization
      expect(oauth).not_to receive(:exchange)
      reset!

      travel Seller::SUPERFRETE_OAUTH_STATE_TTL + 1.second do
        get seller_superfrete_callback_path, params: { code: "valid-code", state: state }
      end

      expect(response).to have_http_status(:bad_request)
      expect(seller.reload).not_to be_superfrete_connected
    end

    it "keeps the previous connection when reading the account fails" do
      seller.connect_superfrete!(access_token: "old", account: Marketplace::SuperfreteOauth::Account.new(id: "sf-old", email: nil))
      state = start_authorization
      allow(oauth).to receive(:exchange).and_return("new-token")
      allow(oauth).to receive(:account).and_raise(Marketplace::SuperfreteOauth::RequestFailed, "A SuperFrete não informou a conta conectada.")
      reset!

      get seller_superfrete_callback_path, params: { code: "valid-code", state: state }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to include("não informou a conta")
      expect(seller.reload.superfrete_access_token).to eq("old")
    end
  end

  context "with remote quotes disabled in the environment" do
    around do |example|
      previous = Rails.configuration.x.shipping.remote_quotes_enabled
      Rails.configuration.x.shipping.remote_quotes_enabled = false
      example.run
    ensure
      Rails.configuration.x.shipping.remote_quotes_enabled = previous
    end

    it "neither offers nor starts the connection" do
      get seller_atelier_path
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{seller_superfrete_connect_path}']")).to be_nil

      expect(oauth).not_to receive(:authorization_url)
      get seller_superfrete_connect_path
      expect(flash[:alert]).to include("indisponível")
    end

    it "refuses a callback without exchanging the code" do
      state = seller.issue_superfrete_oauth_state!
      expect(oauth).not_to receive(:exchange)

      get seller_superfrete_callback_path, params: { code: "codigo", state: state }

      expect(response).to have_http_status(:service_unavailable)

      expect(seller.reload).not_to be_superfrete_connected
    end
  end

  it "disconnects only the current seller" do
    other = Seller.create!(name: "Ateliê Vizinho SuperFrete", owner_full_name: "Outra Pessoa", cpf: "52998224725")
    other.connect_superfrete!(access_token: "other-token", account: Marketplace::SuperfreteOauth::Account.new(id: "sf-2", email: nil))
    seller.connect_superfrete!(access_token: "token", account: account)

    delete seller_superfrete_connection_path

    expect(response).to redirect_to(seller_atelier_path)
    expect(seller.reload).not_to be_superfrete_connected
    expect(other.reload).to be_superfrete_connected
  end

  describe "shipping preference" do
    it "lets the seller choose the provider quote and go back to their own shipping" do
      patch seller_shipping_preference_path, params: { provider_quotes_preferred: "true" }
      expect(response).to redirect_to(seller_atelier_path)
      expect(seller.reload.provider_quotes_preferred).to be(true)

      patch seller_shipping_preference_path, params: { provider_quotes_preferred: "false" }
      expect(seller.reload.provider_quotes_preferred).to be(false)
    end

    it "rejects a request without the choice" do
      patch seller_shipping_preference_path

      expect(response).to have_http_status(:bad_request)
    end

    it "requires a seller login" do
      reset!

      patch seller_shipping_preference_path, params: { provider_quotes_preferred: "true" }

      expect(response).to redirect_to(seller_login_path)
      expect(seller.reload.provider_quotes_preferred).to be(false)
    end
  end

  def start_authorization
    allow(oauth).to receive(:authorization_url) do |state:|
      "https://sandbox.superfrete.com/#/auth/authorize?client_id=x&state=#{CGI.escape(state)}"
    end
    get seller_superfrete_connect_path
    Rack::Utils.parse_query(response.location.split("?", 2).last).fetch("state")
  end
end
