# frozen_string_literal: true

require "rails_helper"

# Fase 25, PR 2 (ADR 007): cadastro, porta de login e painel do armarinho.
# Cada porta só aceita o próprio tipo, com a mesma mensagem genérica das
# outras; um painel não serve o outro tipo; e o cadastro fica atrás da chave
# `config.x.distributors.signup_enabled`, desligada em produção até o advogado
# revisar os termos do distribuidor.
RSpec.describe "Distributor portal", type: :request do
  def create_distributor(status: :pending, accept_terms: true)
    seller = Seller.create!(name: "Fios Atacado #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios",
      cpf: generate_valid_cpf, kind: "distributor", status: status, approved_at: (Time.current if status == :approved))
    user = User.create!(email_address: "fios-#{SecureRandom.hex(3)}@example.com", password: "password123", role: :seller, seller: seller)
    accept_current_seller_terms(user) if accept_terms
    user
  end

  def atelier_user
    User.find_by!(seller: approved_seller)
  end

  def admin_user
    @admin_user ||= User.create!(email_address: "admin-#{SecureRandom.hex(3)}@example.com", password: "password123")
  end

  def distributor_sign_in(user)
    post distributor_login_path, params: { email_address: user.email_address, password: "password123" }
  end

  def atelier_sign_in(user)
    post seller_login_path, params: { email_address: user.email_address, password: "password123" }
  end

  let(:valid_params) do
    {
      seller: { name: "Aviamentos do Sul", owner_full_name: "Joana Sul", cpf: generate_valid_cpf,
                cnpj: "12.ABC.345/01DE-35", issues_invoices: "true" },
      user: { email_address: "aviamentos@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }
  end

  describe "login doors" do
    it "lets a distributor in through /atacado/entrar and lands on the distributor panel" do
      user = create_distributor

      distributor_sign_in(user)

      expect(response).to redirect_to(distributor_root_url)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.seller.name, "Painel do armarinho")
    end

    it "refuses an atelier and an admin at the distributor door with the generic message" do
      [ atelier_user, admin_user ].each do |user|
        distributor_sign_in(user)

        expect(response).to redirect_to(distributor_login_path)
        expect(flash[:alert]).to eq("E-mail ou senha inválidos.")
        expect(cookies[:session_id]).to be_blank
      end
    end

    it "refuses a distributor at the atelier door with the generic message" do
      atelier_sign_in(create_distributor)

      expect(response).to redirect_to(seller_login_path)
      expect(flash[:alert]).to eq("E-mail ou senha inválidos.")
    end

    it "sends a distributor who signs in at the admin door to the distributor panel" do
      user = create_distributor

      post session_path, params: { email_address: user.email_address, password: "password123" }

      expect(response).to redirect_to(distributor_root_url)
    end

    it "signs the distributor out back to its own door" do
      distributor_sign_in(create_distributor)

      delete distributor_logout_path

      expect(response).to redirect_to(distributor_login_path)
      get distributor_root_path
      expect(response).to redirect_to(distributor_login_path)
    end
  end

  describe "panel isolation" do
    it "sends an unauthenticated visitor to the distributor door" do
      get distributor_root_path

      expect(response).to redirect_to(distributor_login_path)
    end

    it "keeps a distributor out of every atelier panel page" do
      distributor_sign_in(create_distributor)

      [ seller_root_path, seller_products_path, new_seller_product_path, seller_orders_path, seller_atelier_path,
        seller_shipping_settings_path, seller_getting_started_path ].each do |path|
        get path
        expect(response).to redirect_to(distributor_root_path), "#{path} should not serve a distributor"
      end
    end

    it "keeps an atelier out of the distributor panel" do
      atelier_sign_in(atelier_user)

      get distributor_root_path

      expect(response).to redirect_to(seller_root_path)
    end

    it "keeps an admin out of the distributor panel" do
      sign_in_as(admin_user)

      get distributor_root_path

      expect(response).to redirect_to(distributor_login_path)
    end

    it "shows only the signed-in distributor's own data, whatever the URL says" do
      user = create_distributor
      other = create_distributor
      distributor_sign_in(user)

      get distributor_root_path(seller_id: other.seller.id)

      expect(response.body).to include(user.seller.name)
      expect(response.body).not_to include(other.seller.name)
    end

    # Vitrine do pré-cadastro, como no painel do ateliê (decisão de 2026-11-07).
    it "tells a pending distributor whether its showcase was released" do
      user = create_distributor
      distributor_sign_in(user)

      get distributor_root_path
      expect(response.body).to include("A EloShop vai liberar a sua vitrine", "Fica pública quando a EloShop liberar a sua vitrine.")

      user.seller.showcase!
      get distributor_root_path
      expect(response.body).to include("Sua vitrine já foi liberada.", "No ar:", distributor_store_path(user.seller.slug))
    end

    it "sends a distributor without the current terms to the distributor terms" do
      distributor_sign_in(create_distributor(accept_terms: false))

      get distributor_root_path

      expect(response).to redirect_to(distributor_terms_path)
      follow_redirect!
      expect(response.body).to include("Termos Comerciais do Distribuidor", SellerTerms.version("distributor"))
    end

    it "records the distributor terms and returns to the distributor panel" do
      user = create_distributor(accept_terms: false)
      distributor_sign_in(user)
      get distributor_root_path

      post distributor_terms_path, params: { terms_accepted: "1" }

      expect(response).to redirect_to(distributor_root_path)
      expect(SellerTermsAcceptance.where(user: user).last.terms_version).to eq(SellerTerms.version("distributor"))
    end
  end

  describe "Mercado Pago connection" do
    it "starts the connection for a distributor through the shared /painel route" do
      user = create_distributor
      distributor_sign_in(user)
      oauth = instance_double(Marketplace::MercadoPagoOauth, authorization_url: "https://auth.mercadopago.com/authorization?x=1")
      allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth)

      get seller_mercado_pago_connect_path

      expect(response).to redirect_to("https://auth.mercadopago.com/authorization?x=1")
    end

    it "returns a distributor to its own panel after a failed callback" do
      distributor_sign_in(create_distributor)

      get seller_mercado_pago_callback_path(state: "forjado", code: "abc")

      expect(response).to redirect_to(distributor_root_path)
    end
  end

  describe "public links to the distributor doors" do
    it "offers the distributor login and signup in the footer and in the mobile menu" do
      get root_path

      footer = Nokogiri::HTML(response.body).at_css("footer").to_html
      expect(footer).to include(distributor_login_path, new_distributor_registration_path)
      mobile_menu = Nokogiri::HTML(response.body).at_css("[data-mobile-menu-target='panel']").to_html
      expect(mobile_menu).to include(distributor_login_path, new_distributor_registration_path)
    end

    it "groups the atelier and distributor doors under \"Venda na EloShop\" in the desktop menu" do
      get root_path

      menu = Nokogiri::HTML(response.body).at_css("#sell-menu")
      links = menu.css("a").map { |link| [ link.text.squish, link["href"] ] }
      expect(links).to include(
        [ "Entrar no Ateliê", seller_login_path ], [ "Cadastre seu Ateliê", new_seller_registration_path ],
        [ "Entrar no Painel do Armarinho", distributor_login_path ], [ "Cadastre seu Armarinho", new_distributor_registration_path ]
      )
    end

    it "does not show the sell menu to a signed-in seller, who gets the own panel instead" do
      distributor_sign_in(create_distributor)

      get root_path

      expect(response.body).not_to include('id="sell-menu"')
    end

    it "points the atelier login page to the distributor door" do
      get seller_login_path

      expect(response.body).to include("Entre pelo Painel do Armarinho", distributor_login_path)
    end

    it "hides the signup link, but not the login, while the signup is switched off" do
      Rails.configuration.x.distributors.signup_enabled = false
      get root_path

      expect(response.body).to include(distributor_login_path)
      expect(response.body).not_to include(new_distributor_registration_path)
    ensure
      Rails.configuration.x.distributors.signup_enabled = true
    end
  end

  describe "public menu" do
    it "points a signed-in distributor to the distributor panel" do
      distributor_sign_in(create_distributor)

      get root_path

      expect(response.body).to include("Painel do Armarinho", distributor_root_path, distributor_logout_path)
      expect(response.body).not_to include("Painel do Artesão")
    end
  end

  describe "registration" do
    it "creates a pending distributor with a new account, records the distributor terms and signs it in" do
      expect do
        post distributor_registration_path, params: valid_params
      end.to change(Seller.distributor, :count).by(1).and change(User.seller, :count).by(1)

      seller = Seller.distributor.find_by!(name: "Aviamentos do Sul")
      expect(seller).to be_pending
      expect(seller.cnpj).to eq("12ABC34501DE35")
      expect(seller.issues_invoices).to be(true)
      acceptance = SellerTermsAcceptance.find_by!(seller: seller)
      expect(acceptance.terms_version).to eq(SellerTerms.version("distributor"))
      expect(response).to redirect_to(distributor_root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "does not send the atelier welcome e-mail to a distributor" do
      expect { post distributor_registration_path, params: valid_params }.not_to have_enqueued_job(SendWelcomeSellerJob)
    end

    it "keeps the invoice declaration unanswered when left blank" do
      post distributor_registration_path, params: valid_params.deep_merge(seller: { issues_invoices: "", cnpj: "" })

      seller = Seller.distributor.find_by!(name: "Aviamentos do Sul")
      expect(seller.issues_invoices).to be_nil
      expect(seller.cnpj).to be_nil
    end

    it "ignores a kind sent by the browser" do
      post distributor_registration_path, params: valid_params.deep_merge(seller: { kind: "atelier" })
      expect(Seller.find_by!(name: "Aviamentos do Sul")).to be_distributor

      post seller_registration_path, params: {
        seller: { name: "Ateliê Esperto", owner_full_name: "Ana", cpf: generate_valid_cpf, kind: "distributor" },
        user: { email_address: "esperto@example.com", password: "password123", password_confirmation: "password123" },
        terms_accepted: "1"
      }
      expect(Seller.find_by!(name: "Ateliê Esperto")).to be_atelier
    end

    it "accepts the CPF of an existing atelier, but not of an existing distributor" do
      cpf = generate_valid_cpf
      Seller.create!(name: "Ateliê da Joana", owner_full_name: "Joana Sul", cpf: cpf)

      post distributor_registration_path, params: valid_params.deep_merge(seller: { cpf: cpf })
      expect(Seller.distributor.where(name: "Aviamentos do Sul")).to exist

      post distributor_registration_path, params: valid_params.deep_merge(
        seller: { name: "Outra Distribuidora", cpf: cpf }, user: { email_address: "outra@example.com" }
      )
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Cada CPF pode ter um único cadastro de armarinho", distributor_login_path)
    end

    # Achado do QA (2026-11-07): dois cadastros com o mesmo CPF ao mesmo
    # tempo passam pela validação e o banco recusa o segundo; a tela dizia
    # "e-mail já está em uso". Simulação da corrida: o concorrente já está
    # gravado, mas a primeira validação não o viu, e o INSERT chega ao índice
    # único.
    it "shows the CPF error, not the e-mail one, when a concurrent signup takes the CPF first" do
      cpf = generate_valid_cpf
      Seller.create!(name: "Concorrente", owner_full_name: "Outra", cpf: cpf, kind: "distributor")
      validations = 0
      allow_any_instance_of(Seller).to receive(:valid?).and_wrap_original do |original, *args, **options|
        validations += 1
        result = original.call(*args, **options)
        next result unless validations == 1

        original.receiver.errors.clear # a primeira validação não viu o concorrente
        true
      end
      allow_any_instance_of(Seller).to receive(:save!).and_wrap_original { |original| original.call(validate: false) }

      post distributor_registration_path, params: valid_params.deep_merge(seller: { cpf: cpf })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Cada CPF pode ter um único cadastro de armarinho")
      expect(response.body).not_to include("já está em uso")
      expect(Seller.where(name: "Aviamentos do Sul")).to be_empty
    end

    it "shows an invalid CNPJ with its hint and keeps what was typed" do
      post distributor_registration_path, params: valid_params.deep_merge(seller: { cnpj: "11.222.333/0001-00" })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("O CNPJ tem 14 caracteres", "11.222.333/0001-00", "Aviamentos do Sul")
      expect(Seller.distributor.count).to eq(0)
    end

    it "refuses without the terms and when the Turnstile refuses" do
      post distributor_registration_path, params: valid_params.except(:terms_accepted)
      expect(response).to have_http_status(:unprocessable_entity)

      allow(Turnstile).to receive(:verify).and_return(:failed)
      post distributor_registration_path, params: valid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Seller.distributor.count).to eq(0)
    end

    # ADR 007 (2026-11-07): a loja do distribuidor fica em /distribuidores/:slug.
    it "tells the distributor which store address the name reserves" do
      get new_distributor_registration_path
      expect(response.body).to include("https://eloshop.shop/armarinhos/aviamentos-do-sul", "o endereço não muda")

      post distributor_registration_path, params: valid_params
      follow_redirect!
      expect(response.body).to include("/armarinhos/aviamentos-do-sul")
    end

    it "links the distributor terms from the form" do
      get new_distributor_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(distributor_terms_path, SellerTerms.version("distributor"), 'name="robots" content="noindex"')
    end

    it "shows the distributor terms to a visitor at /atacado/termos-comerciais" do
      get distributor_terms_path

      expect(response.body).to include("Termos Comerciais do Distribuidor", SellerTerms.version("distributor"))
      expect(response.body).not_to include(SellerTerms.version("atelier"))
    end

    context "with the signup switched off, as in production until the lawyer reviews the terms" do
      around do |example|
        Rails.configuration.x.distributors.signup_enabled = false
        example.run
      ensure
        Rails.configuration.x.distributors.signup_enabled = true
      end

      it "answers 404 to the form and to the submission, and creates nothing" do
        get new_distributor_registration_path
        expect(response).to have_http_status(:not_found)

        expect { post distributor_registration_path, params: valid_params }.not_to change(Seller, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "still lets an existing distributor sign in and hides the signup link" do
        user = create_distributor

        get distributor_login_path
        expect(response.body).not_to include(new_distributor_registration_path)

        distributor_sign_in(user)
        expect(response).to redirect_to(distributor_root_url)
      end
    end
  end
end
