# frozen_string_literal: true

require "rails_helper"

# Painel do armarinho reaproveitando o do ateliê (ADR 007; revisão de
# arquitetura de 2026-11-07, opção B): as telas compartilhadas moram em
# /atacado/painel por subclasse, com o layout e a porta do distribuidor; o
# /painel continua só de ateliê. Cada tela recusa o tipo errado e o escopo
# vem sempre da sessão.
RSpec.describe "Distributor panel", type: :request do
  def create_distributor(name: "Fios #{SecureRandom.hex(3)}")
    seller = Seller.create!(name: name, owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf, kind: "distributor")
    user = User.create!(email_address: "painel-#{SecureRandom.hex(3)}@example.com", password: "password123", role: :seller, seller: seller)
    accept_current_seller_terms(user)
    user
  end

  def sign_in_distributor(user)
    post distributor_login_path, params: { email_address: user.email_address, password: "password123" }
  end

  let(:user) { create_distributor }
  let(:distributor) { user.seller }

  PANEL_PATHS = %i[distributor_root_path distributor_getting_started_path distributor_profile_path edit_distributor_profile_path
                   distributor_mercado_pago_guide_path distributor_pix_key_guide_path distributor_notifications_path].freeze

  describe "access" do
    it "opens every panel screen for the distributor, with the distributor layout" do
      sign_in_distributor(user)

      PANEL_PATHS.each do |helper|
        get send(helper)
        expect(response).to have_http_status(:ok), "#{helper} answered #{response.status}"
        expect(response.body).to include("Atacado", distributor_logout_path), "#{helper} is not in the distributor layout"
        expect(response.body).not_to include(seller_logout_path), "#{helper} rendered the atelier layout"
      end
    end

    it "sends a visitor to the distributor door, an atelier to its own panel and an admin to the distributor door" do
      PANEL_PATHS.each do |helper|
        get send(helper)
        expect(response).to redirect_to(distributor_login_path), "#{helper} let a visitor in"
      end

      post seller_login_path, params: { email_address: User.find_by!(seller: approved_seller).email_address, password: "password123" }
      PANEL_PATHS.each do |helper|
        get send(helper)
        expect(response).to redirect_to(seller_root_path), "#{helper} let an atelier in"
      end
      delete seller_logout_path

      admin = User.create!(email_address: "adm-painel-#{SecureRandom.hex(3)}@example.com", password: "password123")
      post session_path, params: { email_address: admin.email_address, password: "password123" }
      get distributor_getting_started_path
      expect(response).to redirect_to(distributor_login_path)
    end

    it "keeps the atelier panel screens closed to the distributor" do
      sign_in_distributor(user)

      [ seller_getting_started_path, seller_notifications_path, seller_pix_key_guide_path, edit_seller_atelier_path ].each do |path|
        get path
        expect(response).to redirect_to(distributor_root_path), "#{path} served a distributor"
      end
    end
  end

  describe "getting started" do
    it "shows the distributor steps, with the first supply and without SuperFrete or the atelier tour" do
      sign_in_distributor(user)

      get distributor_getting_started_path

      expect(response.body).to include("0 de 5 etapas concluídas", "Endereço de origem", "Conta do Mercado Pago", "Chave PIX", "Primeiro insumo", "Aprovação e recebimento")
      expect(response.body).not_to include("Primeira peça", "SuperFrete", "Fazer tour pelo painel", "Endereço do ateliê")
    end

    it "fills the origin address from the overview block and moves on, inside the distributor panel" do
      sign_in_distributor(user)

      patch distributor_origin_address_path, params: { seller: { origin_zip_code: "01310-100", origin_street: "Av. Paulista",
        origin_number: "1000", origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP" } }

      expect(response).to redirect_to(distributor_root_path)
      expect(distributor.reload).to be_origin_address_complete
      follow_redirect!
      expect(response.body).to include("1 de 5 etapas concluídas")
    end

    it "keeps an incomplete address in the block with the error" do
      sign_in_distributor(user)

      patch distributor_origin_address_path, params: { seller: { origin_zip_code: "01310-100" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Preencha o endereço de origem")
    end

    it "records and undoes the PIX key declaration, coming back to the distributor panel" do
      sign_in_distributor(user)

      post distributor_pix_key_confirmation_path
      expect(response).to redirect_to(distributor_getting_started_path)
      expect(distributor.reload.pix_key_confirmed_at).to be_present

      delete distributor_pix_key_confirmation_path
      expect(distributor.reload.pix_key_confirmed_at).to be_nil
    end
  end

  describe "notifications" do
    it "lists only the distributor's own notifications and opens one, never another seller's" do
      mine = Notification.create!(recipient: distributor, kind: :seller_suspended, title: "Aviso meu", body: "corpo", url: distributor_profile_path)
      other = Notification.create!(recipient: create_distributor.seller, kind: :seller_suspended, title: "Aviso de outro", body: "corpo", url: "/")
      sign_in_distributor(user)

      get distributor_notifications_path
      expect(response.body).to include("Aviso meu")
      expect(response.body).not_to include("Aviso de outro")

      patch mark_as_read_distributor_notification_path(mine)
      expect(response).to redirect_to(distributor_profile_path)
      expect(mine.reload).to be_read

      patch mark_as_read_distributor_notification_path(other)
      expect(response).to have_http_status(:not_found)
      expect(other.reload).not_to be_read
    end
  end

  describe "distributor data" do
    it "updates name, responsible, CNPJ, invoice declaration and origin address" do
      sign_in_distributor(user)

      patch distributor_profile_path, params: { seller: {
        name: "Fios Renomeados", owner_full_name: "Joana Fios", cnpj: "12.abc.345/01de-35", issues_invoices: "false",
        origin_zip_code: "01310-100", origin_street: "Av. Paulista", origin_number: "1000", origin_complement: "Sala 3",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP"
      } }

      expect(response).to redirect_to(distributor_profile_path)
      distributor.reload
      expect(distributor.name).to eq("Fios Renomeados")
      expect(distributor.cnpj).to eq("12ABC34501DE35")
      expect(distributor.issues_invoices).to be(false)
      expect(distributor.origin_complement).to eq("Sala 3")
      follow_redirect!
      expect(response.body).to include("Fios Renomeados", "12.ABC.345/01DE-35", "Sala 3")
    end

    it "ignores status, kind, slug and approval sent by the browser" do
      sign_in_distributor(user)
      slug = distributor.slug

      patch distributor_profile_path, params: { seller: { name: "Fios Esperto", status: "approved", kind: "atelier", slug: "outro", approved_at: Time.current, showcased_at: Time.current } }

      distributor.reload
      expect(distributor).to be_pending
      expect(distributor).to be_distributor
      expect(distributor.slug).to eq(slug)
      expect(distributor.showcased_at).to be_nil
    end

    it "shows an invalid CNPJ back on the form" do
      sign_in_distributor(user)

      patch distributor_profile_path, params: { seller: { cnpj: "11.222.333/0001-00" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(distributor.reload.cnpj).to be_nil
    end

    it "looks up a CEP through the distributor panel" do
      allow(PostalCodeLookup).to receive(:new).and_return(instance_double(PostalCodeLookup,
        call: PostalCodeLookup::Address.new(street: "Av. Paulista", neighborhood: "Bela Vista", city: "São Paulo", state: "SP")))
      sign_in_distributor(user)

      get distributor_profile_postal_code_path(cep: "01310100")

      expect(response.parsed_body).to include("street" => "Av. Paulista", "city" => "São Paulo")
    end
  end

  describe "phone tabs" do
    # O rótulo visível de cada aba, sem o texto só para leitor de tela.
    def tab_labels
      Nokogiri::HTML(response.body).css("nav[data-mobile-tabs] li a").map { |link| link.xpath("./span[2]").text.squish }
    end

    it "shows the setup tabs while a step is missing, marking the next one" do
      sign_in_distributor(user)

      get distributor_root_path

      expect(tab_labels).to eq([ "Início", "Endereço", "Mercado Pago", "PIX", "Insumo" ])
      expect(response.body).to include("(próxima etapa)")
    end

    it "shows the day-to-day tabs once every step is done" do
      distributor.update_columns(origin_zip_code: "01310100", origin_street: "Av. Paulista", origin_number: "1000", origin_neighborhood: "Bela Vista",
        origin_city: "São Paulo", origin_state: "SP", pix_key_confirmed_at: Time.current, status: "approved", approved_at: Time.current,
        mercado_pago_user_id: "mp-painel", mercado_pago_access_token_ciphertext: "x", mercado_pago_refresh_token_ciphertext: "y",
        mercado_pago_connected_at: Time.current, mercado_pago_live_mode: true, mercado_pago_test_account: false)
      distributor.products.create!(name: "Fio cru", price_cents: 2_500, stock_quantity: 10)
      sign_in_distributor(user)

      get distributor_root_path

      expect(tab_labels).to eq([ "Início", "Insumos", "Novo insumo", "Avisos", "Dados" ])
      expect(response.body).not_to include("etapas concluídas")
    end
  end
end
