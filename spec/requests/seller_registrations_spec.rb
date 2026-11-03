require "rails_helper"

RSpec.describe "Seller registrations", type: :request do
  describe "GET name availability" do
    it "reports a taken name and suggests a free one" do
      Seller.create!(name: "Ateliê da Ana", owner_full_name: "Ana", cpf: "11144477735")

      get seller_registration_name_availability_path(name: "atelie da ana")

      body = response.parsed_body
      expect(body).to include("available" => false, "suggestion" => "atelie da ana 2")
    end

    it "reports a free name" do
      get seller_registration_name_availability_path(name: "Ateliê Livre")

      expect(response.parsed_body).to include("available" => true, "slug" => "atelie-livre")
    end
  end

  it "invites artisans to pre-register while sales are closed" do
    PlatformSetting.instance.update!(sales_opened_at: nil)

    get new_seller_registration_path

    expect(response.body).to include("Pré-cadastro aberto", "Monte sua loja agora e comece a vender na abertura.", "As vendas da EloShop abrem em breve.", "Começar meu cadastro")
  end

  it "drops the pre-registration invitation once sales are open" do
    get new_seller_registration_path

    expect(response.body).not_to include("Pré-cadastro aberto")
  end

  it "describes the signup page with its own meta description" do
    get new_seller_registration_path

    expect(response.body).to include('<meta name="description" content="Cadastre seu ateliê na EloShop')
  end

  it "tells the seller what to have ready before signing up" do
    get new_seller_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Antes de começar")
    expect(response.body).to include("conta de vendedor do Mercado Pago")
    expect(response.body).to include(how_it_works_path(aba: "vende"))
  end

  it "tells the seller about the launch commission before signing up" do
    get new_seller_registration_path

    expect(response.body).to include("8% nos 3 primeiros meses de vendas")
    expect(response.body).to include("Não há mensalidade, no momento.")
  end

  it "has a title aimed at artisans who want to sell" do
    get new_seller_registration_path

    expect(response.body).to include("<title>Venda seu artesanato online: cadastre seu ateliê | EloShop</title>")
  end

  it "warns that the atelier URL does not change when the name does" do
    get new_seller_registration_path

    expect(response.body).to include("https://eloshop.shop/artesaos/atelie-da-ana")
    expect(response.body).to include("a URL não será alterada")
  end

  it "creates a pending seller account and signs it in" do
    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê da Serra", owner_full_name: "Maria Serra", cpf: "60000000060" },
        user: { email_address: "serra@example.com", password: "password123", password_confirmation: "password123" },
        terms_accepted: "1"
      }
    end.to change(Seller, :count).by(1).and change(User.seller, :count).by(1)
      .and have_enqueued_job(SendWelcomeSellerJob)

    seller = Seller.find_by!(slug: "atelie-da-serra")
    expect(seller).to be_pending
    expect(SellerTermsAcceptance.exists?(seller: seller, terms_version: SellerTerms.version)).to be(true)
    expect(response).to redirect_to(seller_root_path)
  end

  it "does not persist either record when the account is invalid" do
    seller_count = Seller.count
    user_count = User.count

    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Inválido", owner_full_name: "Dono Inválido", cpf: "70000000078" },
        user: { email_address: "invalido@example.com", password: "short", password_confirmation: "different" }
      }
    end.not_to change(Seller, :count)

    expect(Seller.count).to eq(seller_count)
    expect(User.count).to eq(user_count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Antes, `@seller.valid? && @user.valid?` parava no primeiro inválido: com o
  # CPF errado, os erros de e-mail e senha nem eram calculados, e o artesão só
  # os descobria na tentativa seguinte.
  it "lists every error of the atelier, the account and the terms at once" do
    post seller_registration_path, params: {
      seller: { name: "", owner_full_name: "", cpf: "123" },
      user: { email_address: "", password: "short", password_confirmation: "different" }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include(
      "Nome do ateliê não pode ficar em branco",
      "Nome completo do responsável não pode ficar em branco",
      "CPF deve ter 11 dígitos",
      "E-mail não pode ficar em branco",
      "Confirmação da senha não é igual a Senha",
      "aceite os termos comerciais para criar o cadastro"
    )
    expect(body).to include("Corrija 6 erros para continuar:")
    expect(body).not_to include("URL do ateliê não pode ficar em branco")
    expect(response.body).to include('data-controller="error-summary"')
  end

  it "repeats each error right below its own field" do
    post seller_registration_path, params: {
      seller: { name: "Ateliê Campo", owner_full_name: "Dona Campo", cpf: "123" },
      user: { email_address: "campo@example.com", password: "password123", password_confirmation: "outra-senha" }
    }

    page = Nokogiri::HTML(response.body)
    cpf = page.at_css("#seller_cpf")
    expect(cpf["aria-invalid"]).to eq("true")
    expect(cpf["aria-describedby"]).to eq("seller_cpf_check seller_cpf_error")
    expect(page.at_css("#seller_cpf_error").text.squish).to eq("CPF deve ter 11 dígitos. O CPF tem 11 números. Confira se faltou ou sobrou algum.")
    expect(page.at_css("#user_password_confirmation_error").text.squish).to eq("Confirmação da senha não é igual a Senha. Digite a mesma senha nos dois campos.")
    expect(page.at_css("#user_email_address")["aria-invalid"]).to be_nil
    expect(page.at_css("#erros-cadastro-gerais").text).to include("aceite os termos comerciais")
  end

  it "explains a CPF that already has an atelier and points to the login" do
    cpf = generate_valid_cpf
    Seller.create!(name: "Ateliê Primeiro #{SecureRandom.hex(3)}", owner_full_name: "Dona Primeira", cpf: cpf)

    post seller_registration_path, params: {
      seller: { name: "Ateliê Segundo #{SecureRandom.hex(3)}", owner_full_name: "Dona Segunda", cpf: Seller.format_cpf(cpf) },
      user: { email_address: "segundo-#{SecureRandom.hex(3)}@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }

    page = Nokogiri::HTML(response.body)
    summary = page.at_css("#erros-cadastro").text.squish
    expect(summary).to include("CPF já está cadastrado para outro ateliê.", "Cada CPF pode ter um único ateliê na EloShop.")
    expect(page.at_css("#erros-cadastro a[href='#{seller_login_path}']")).to be_present
  end

  it "explains an e-mail that already has an account" do
    User.create!(email_address: "ja-existe@example.com", password: "password123")

    post seller_registration_path, params: {
      seller: { name: "Ateliê E-mail #{SecureRandom.hex(3)}", owner_full_name: "Dona E-mail", cpf: generate_valid_cpf },
      user: { email_address: "ja-existe@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }

    summary = Nokogiri::HTML(response.body).at_css("#erros-cadastro").text.squish
    expect(summary).to include("E-mail já está em uso.", "Já existe uma conta com este e-mail.")
  end

  # Sem o rescue, o token vencido caía na página 422 padrão do Rails, em
  # inglês ("The change you wanted was rejected") e sem dizer o que fazer.
  it "explains an expired form instead of the default 422 page, keeping what was typed" do
    ActionController::Base.allow_forgery_protection = true

    post seller_registration_path, params: {
      authenticity_token: "vencido",
      seller: { name: "Ateliê Expirado", owner_full_name: "Dona Expirada", cpf: "52998224725" },
      user: { email_address: "expirado@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }

    expect(response).to have_http_status(:unprocessable_content)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include(SellerRegistrationsController::EXPIRED_FORM_MESSAGE)
    expect(body).not_to include("The change you wanted was rejected")
    expect(body).to include('value="Ateliê Expirado"', 'value="529.982.247-25"', 'value="expirado@example.com"')
    expect(Seller.where(name: "Ateliê Expirado")).not_to exist
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "explains the attempt limit instead of a generic message" do
    6.times do
      post seller_registration_path, params: { seller: { name: "", owner_full_name: "", cpf: "" }, user: { email_address: "", password: "", password_confirmation: "" } }
    end

    expect(response).to redirect_to(new_seller_registration_path(anchor: "cadastro"))
    expect(flash[:alert]).to eq(SellerRegistrationsController::RATE_LIMIT_MESSAGE)
  end

  it "records which validations failed, without the typed values" do
    events = []
    subscriber = Class.new { define_method(:emit) { |event| events << event } }.new
    Rails.event.subscribe(subscriber)

    post seller_registration_path, params: {
      seller: { name: "Ateliê Log", owner_full_name: "Dona Log", cpf: "12345" },
      user: { email_address: "segredo-log@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }

    event = events.find { |e| e[:name] == "marketplace.seller_registration_failed" }
    expect(event[:payload][:seller_errors]).to eq([ "cpf:deve ter 11 dígitos" ])
    expect(event[:payload].to_s).not_to include("12345", "segredo-log")
  ensure
    Rails.event.unsubscribe(subscriber)
  end

  it "returns the typed CPF formatted when the form comes back with errors" do
    post seller_registration_path, params: {
      seller: { name: "Ateliê CPF", owner_full_name: "Dona CPF", cpf: "11111111111" },
      user: { email_address: "cpf@example.com", password: "password123", password_confirmation: "password123" },
      terms_accepted: "1"
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('value="111.111.111-11"')
    expect(response.body).to include("CPF é inválido")
    expect(response.body).to include('data-controller="cpf-input"')
  end

  it "accepts a CPF typed with the mask" do
    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Máscara #{SecureRandom.hex(3)}", owner_full_name: "Dona Máscara", cpf: Seller.format_cpf(generate_valid_cpf) },
        user: { email_address: "mascara-#{SecureRandom.hex(3)}@example.com", password: "password123", password_confirmation: "password123" },
        terms_accepted: "1"
      }
    end.to change(Seller, :count).by(1)
  end

  it "shows a translated error when the email address is already registered" do
    User.create!(email_address: "existing@example.com", password: "password123")

    expect do
      post seller_registration_path, params: {
        seller: { name: "Ateliê Existente", owner_full_name: "Dono Existente", cpf: "80000000086" },
        user: { email_address: "existing@example.com", password: "password123", password_confirmation: "password123" }
      }
    end.not_to change(Seller, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("E-mail já está em uso")
    expect(response.body).not_to include("Translation missing")
  end

  describe "anti-abuse" do
    let(:signup) do
      {
        seller: { name: "Ateliê Anti", owner_full_name: "Maria Anti", cpf: "60000000060" },
        user: { email_address: "anti@example.com", password: "password123", password_confirmation: "password123" },
        terms_accepted: "1"
      }
    end

    it "creates nothing when the Turnstile refuses the token" do
      allow(Turnstile).to receive(:verify).and_return(:failed)

      expect { post seller_registration_path, params: signup }.not_to change(Seller, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lists the other errors along with the Turnstile refusal" do
      allow(Turnstile).to receive(:verify).and_return(:failed)

      post seller_registration_path, params: signup.merge(
        seller: signup[:seller].merge(cpf: "123"), terms_accepted: nil
      )

      body = CGI.unescapeHTML(response.body)
      expect(body).to include(EmailAbuseProtection::TURNSTILE_ERROR, "CPF deve ter 11 dígitos", "aceite os termos comerciais")
    end

    it "still registers but sends no welcome e-mail once the daily account e-mail limit is reached" do
      Rails.cache.write("email_budget:account:#{Date.current.iso8601}", EmailAbuseProtection::DAILY_ACCOUNT_EMAIL_LIMIT, expires_in: 1.day)

      expect { post seller_registration_path, params: signup }.to change(Seller, :count).by(1)
      expect(SendWelcomeSellerJob).not_to have_been_enqueued
    end
  end
end
