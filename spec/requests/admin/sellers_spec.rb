require "rails_helper"

RSpec.describe "Admin sellers", type: :request do
  before do
    SellerTermsAcceptance.delete_all
    Session.delete_all
    FunnelEvent.delete_all
    OrderMessage.delete_all
    Shipment.delete_all
    clear_product_data!
    SellerOrder.delete_all
    User.delete_all
    Seller.delete_all
  end

  let(:admin) { User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:seller) { Seller.create!(name: "Ateliê Pendente #{SecureRandom.hex(4)}", owner_full_name: "Proprietário Teste", cpf: "10666670200") }
  let(:seller_user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }

  it "shows each seller's onboarding stage on the list and on the detail page" do
    seller
    sign_in_as(admin)

    get admin_sellers_path
    expect(response.body).to include("Falta conectar o Mercado Pago")

    get admin_seller_path(seller)
    expect(response.body).to include("Falta conectar o Mercado Pago")
  end

  it "lets platform admins approve a seller" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    connect_superfrete!(seller)

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_approved
  end

  it "emails the seller when approved" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    connect_superfrete!(seller)

    expect do
      patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }
    end.to have_enqueued_job(NotifySellerOfApprovalJob).with(seller)
  end

  it "does not approve without a connected Mercado Pago account" do
    sign_in_as(admin)

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_pending
  end

  # `live_mode` sozinho não distingue TESTUSER de conta real — ver o
  # comentário em Seller#mercado_pago_real_account?. Uma conta de sandbox
  # já foi aprovada indevidamente antes dessa checagem existir.
  it "does not approve a Mercado Pago sandbox (TESTUSER) account" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(false)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true))

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_pending
  end

  # O formulário desabilitava por `mercado_pago_live_mode?`, critério que
  # deixou de valer quando a aprovação passou a aceitar conta de teste em
  # sandbox: sem isto o modelo aprovaria e a tela não deixaria nem marcar a
  # caixa do KYC.
  it "enables the approval form for a test account while the app runs in sandbox mode" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(true)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true, live_mode: false))
    connect_superfrete!(seller)

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    checkbox = Nokogiri::HTML(response.body).at_css("input#kyc_level_6_confirmed")
    expect(checkbox["disabled"]).to be_nil
    expect(Nokogiri::HTML(response.body).at_css("input[type=submit][value='Aprovar artesão']")["disabled"]).to be_nil
  end

  it "keeps the approval form disabled for a test account outside sandbox mode" do
    sign_in_as(admin)
    allow(Marketplace::MercadoPagoOauth).to receive(:sandbox?).and_return(false)
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: true, live_mode: false))

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("input#kyc_level_6_confirmed")["disabled"]).to eq("disabled")
  end

  # A conexão com a SuperFrete é obrigatória para aprovar (decisão de
  # 2026-11-04): a tela desabilita e o servidor recusa, pela mesma regra.
  it "does not approve a seller without SuperFrete, in the form and on the server" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    get admin_seller_path(seller)
    expect(response.body).to include("A conta da SuperFrete ainda não está conectada")
    expect(Nokogiri::HTML(response.body).at_css("input[type=submit][value='Aprovar artesão']")["disabled"]).to eq("disabled")

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }
    expect(seller.reload).not_to be_approved
  end

  it "shows the seller's own connection link when Mercado Pago is not connected yet" do
    sign_in_as(admin)

    get admin_seller_path(seller)

    expect(response.body).to include("Conta ainda não conectada")
    expect(response.body).to include(seller_atelier_url)
  end

  it "does not show the connection link once Mercado Pago is connected" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    get admin_seller_path(seller)

    expect(response.body).not_to include(seller_atelier_url)
  end

  it "shows the owner's full name and complete CPF on the seller detail page" do
    sign_in_as(admin)

    get admin_seller_path(seller)

    expect(response.body).to include("Proprietário Teste")
    expect(response.body).to include(seller.cpf_for_admin)
    expect(response.body).to include("106.666.702-00")
  end

  it "shows the count of pending reports and a link filtered by this seller" do
    sign_in_as(admin)
    reporting_customer = Customer.create!(name: "Cliente denúncia seller show", email: "denuncia-seller-show@example.com", password: "password123")
    reporting_customer.seller_reports.create!(seller: seller, reason: "fraud")

    get admin_seller_path(seller)

    expect(response.body).to include("1 denúncia pendente")
    expect(response.body).to include(admin_seller_reports_path(seller_id: seller.id))
  end

  it "shows no pending reports when the seller has none" do
    sign_in_as(admin)

    get admin_seller_path(seller)

    expect(response.body).to include("Nenhuma denúncia pendente")
  end

  it "shows a dash on the detail page when the owner data was never filled in" do
    sign_in_as(admin)
    seller.update_columns(owner_full_name: nil, cpf_ciphertext: nil, cpf_hash: nil)

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dados do proprietário")
  end

  it "shows the owner's full name and complete CPF in the seller list" do
    sign_in_as(admin)
    seller # ensure the seller record exists before the page renders

    get admin_sellers_path

    expect(response.body).to include("Proprietário Teste")
    expect(response.body).to include(seller.cpf_for_admin)
    expect(response.body).to include("106.666.702-00")
  end

  it "shows the current commercial terms acceptance for the seller" do
    sign_in_as(admin)
    acceptance = SellerTermsAcceptance.create!(
      user: seller_user,
      seller: seller,
      terms_version: SellerTerms.version,
      terms_text: SellerTerms.text,
      terms_digest: Digest::SHA256.hexdigest(SellerTerms.text),
      accepted_at: Time.current,
      ip_address: "127.0.0.1",
      user_agent: "AdminSpec/1.0"
    )

    get admin_seller_path(seller)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Termos Comerciais do Marketplace")
    expect(response.body).to include(acceptance.terms_version)
    expect(response.body).to include(acceptance.user.email_address)
  end

  it "shows pending commercial terms status in the seller list" do
    sign_in_as(admin)
    seller # ensure the seller record exists before the page renders

    get admin_sellers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Termos")
    expect(response.body).to include("Pendente")
    expect(response.body).to include(seller.name)
    expect(response.body).to include("Em risco")
    expect(response.body).to include("Termos pendentes")
    expect(response.body).to include("Suspensos")
  end

  it "filters sellers by commercial terms status" do
    sign_in_as(admin)
    accepted_seller = Seller.create!(name: "Ateliê Aceito #{SecureRandom.hex(4)}", owner_full_name: "Proprietário Teste", cpf: "10777781980")
    accepted_user = User.create!(email_address: "seller-accepted-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: accepted_seller)
    SellerTermsAcceptance.create!(
      user: accepted_user,
      seller: accepted_seller,
      terms_version: SellerTerms.version,
      terms_text: SellerTerms.text,
      terms_digest: Digest::SHA256.hexdigest(SellerTerms.text),
      accepted_at: Time.current,
      ip_address: "127.0.0.1",
      user_agent: "AdminSpec/1.0"
    )

    get admin_sellers_path(terms: "pending_terms")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(accepted_seller.name)

    get admin_sellers_path(terms: "accepted")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(accepted_seller.name)
  end

  it "combines marketplace status and pending terms filters" do
    sign_in_as(admin)
    pending_terms_seller = Seller.create!(name: "Ateliê sem termos #{SecureRandom.hex(4)}", owner_full_name: "Proprietário Teste", cpf: "10888893604", status: :approved)
    User.create!(email_address: "seller-terms-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: pending_terms_seller)

    get admin_sellers_path(status: "approved", terms: "pending_terms")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(pending_terms_seller.name)
  end

  it "paginates sellers" do
    sign_in_as(admin)
    per_page = Paginatable::DEFAULT_PER_PAGE
    (per_page * 2 - Seller.count).times { |i| Seller.create!(name: "Ateliê Paginação #{i} #{SecureRandom.hex(3)}", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf) }

    get admin_sellers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Página 1 de 2")
  end

  it "keeps the platform panel unavailable to sellers" do
    sign_in_as(seller_user)

    get admin_sellers_path

    expect(response).to redirect_to(new_session_path)
  end

  it "lets platform admins hide an approved seller from the storefront" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    connect_superfrete!(seller)
    seller.approve!(kyc_level_6_confirmed: true)

    patch hide_admin_seller_path(seller)

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_hidden
    expect(seller).to be_approved
  end

  it "notifies the seller when the platform suspends the account" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    connect_superfrete!(seller)
    seller.approve!(kyc_level_6_confirmed: true)

    patch suspend_admin_seller_path(seller)

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).to be_suspended
    notification = seller.notifications.seller_suspended.last
    expect(notification).to be_present
  end

  it "suspends and notifies the owner's seller of the other kind together" do
    sign_in_as(admin)
    distributor = Seller.create!(name: "Fios do Mesmo Dono", owner_full_name: "Proprietário Teste", cpf: "10666670200", kind: "distributor")

    patch suspend_admin_seller_path(seller)

    expect(seller.reload).to be_suspended
    expect(distributor.reload).to be_suspended
    expect(seller.notifications.seller_suspended).to exist
    expect(distributor.notifications.seller_suspended).to exist
  end

  it "filters the seller list by kind" do
    seller
    distributor = Seller.create!(name: "Fios Atacado Filtro", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf, kind: "distributor")
    sign_in_as(admin)

    get admin_sellers_path(kind: "distributor")
    expect(response.body).to include(distributor.name)
    expect(response.body).to include("Distribuidor de insumos")
    expect(response.body).not_to include(seller.name)

    get admin_sellers_path(kind: "atelier")
    expect(response.body).to include(seller.name)
    expect(response.body).not_to include(distributor.name)

    get admin_sellers_path(kind: "anything")
    expect(response.body).to include(seller.name)
    expect(response.body).to include(distributor.name)
  end

  it "lets platform admins unhide a seller" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    connect_superfrete!(seller)
    seller.approve!(kyc_level_6_confirmed: true)
    seller.hide!

    patch unhide_admin_seller_path(seller)

    expect(response).to redirect_to(admin_seller_path(seller))
    expect(seller.reload).not_to be_hidden
  end

  it "records which admin approved, suspended and hid a seller" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    before = seller.versions.count

    patch approve_admin_seller_path(seller), params: { kyc_level_6_confirmed: "1" }
    patch hide_admin_seller_path(seller)
    patch suspend_admin_seller_path(seller)

    versions = seller.versions.offset(before)
    expect(versions.map(&:whodunnit).uniq).to eq([ admin.id.to_s ])
    expect(versions.flat_map { |v| v.object_changes.keys }).to include("status", "hidden_at")
    expect(versions.map { |v| v.object_changes.to_json }.join).not_to match(/ciphertext|access-token/)
  end

  def mercado_pago_credentials(test_account: false, live_mode: true)
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "admin-spec-seller",
      access_token: "access-token",
      refresh_token: "refresh-token",
      expires_at: 180.days.from_now,
      live_mode: live_mode,
      test_account: test_account,
      public_key: "TEST-public-key"
    )
  end

  # ADR 007: a ficha do distribuidor não mostra vitrine nem SuperFrete, chama
  # o vendedor pelo tipo e manda o link do painel do distribuidor.
  describe "a distributor's page" do
    let(:distributor) do
      Seller.create!(name: "Fios Admin #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf,
        kind: "distributor", cnpj: "12.ABC.345/01DE-35", issues_invoices: true)
    end

    it "shows the distributor without the artisan showcase and SuperFrete" do
      sign_in_as(admin)

      get admin_seller_path(distributor)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".admin-section-label").text).to eq("Distribuidor de insumos")
      expect(response.body).to include("12.ABC.345/01DE-35", "Emite nota fiscal: sim", "Termos Comerciais do Distribuidor", distributor_root_url)
      expect(response.body).not_to include("Liberar na vitrine", "Esconder da vitrine", "Vitrine do pré-cadastro", "SuperFrete", seller_atelier_url)
      expect(page.at_css("input[type=submit][value='Aprovar distribuidor']")).to be_present
    end

    it "approves the distributor with a notice that names the kind" do
      sign_in_as(admin)
      distributor.connect_mercado_pago!(mercado_pago_credentials)

      patch approve_admin_seller_path(distributor), params: { kyc_level_6_confirmed: "1" }

      expect(distributor.reload).to be_approved
      expect(flash[:notice]).to eq("Distribuidor aprovado.")
    end

    # Decisão de 2026-11-07 (opção A): esconder vale para o distribuidor, sem
    # suspender, com aviso do próprio tipo.
    it "hides and shows a distributor again, with notices that name the kind" do
      sign_in_as(admin)

      patch hide_admin_seller_path(distributor)
      expect(distributor.reload).to be_hidden
      expect(flash[:notice]).to eq("Distribuidor escondido: a loja e os insumos dele ficam fora do ar.")
      expect(distributor).not_to be_suspended

      patch unhide_admin_seller_path(distributor)
      expect(distributor.reload).not_to be_hidden
      expect(flash[:notice]).to eq("Distribuidor visível de novo: a loja e os insumos dele voltam ao ar.")
    end

    it "refuses to take a distributor out of the artisan showcase" do
      sign_in_as(admin)

      patch unshowcase_admin_seller_path(distributor)

      expect(flash[:alert]).to eq("Distribuidor não aparece na vitrine de peças.")
    end

    it "refuses to release a distributor to the artisan showcase" do
      sign_in_as(admin)

      patch showcase_admin_seller_path(distributor)

      expect(flash[:alert]).to eq("Distribuidor não aparece na vitrine de peças.")
      expect(distributor.reload.showcased_at).to be_nil
    end
  end
end
