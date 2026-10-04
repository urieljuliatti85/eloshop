require "rails_helper"

RSpec.describe "Seller tour", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Tour", owner_full_name: "Proprietário Teste", cpf: "13444462727", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Ateliê Outro Tour", owner_full_name: "Proprietário Teste", cpf: "13555574450", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "tour-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: true, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  describe "automatic start" do
    it "starts on its own while the seller has not completed the tour" do
      sign_in_as(user)

      get seller_root_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("body")["data-controller"]).to eq("tour")
      expect(doc.at_css("body")["data-tour-auto-value"]).to eq("true")
      steps = JSON.parse(doc.at_css("body")["data-tour-steps-value"])
      expect(steps.map { |step| step["path"] }).to eq([
        seller_getting_started_path, seller_atelier_path, seller_mercado_pago_guide_path, new_seller_product_path
      ])
    end

    it "does not start on its own once completed" do
      seller.update!(tour_completed_at: Time.current)
      sign_in_as(user)

      get seller_root_path

      expect(Nokogiri::HTML(response.body).at_css("body")["data-tour-auto-value"]).to eq("false")
    end
  end

  describe "call on the dashboard" do
    def tour_button_label
      Nokogiri::HTML(response.body).at_css("section[aria-labelledby='tour-call-title'] button[data-action='tour#start']")&.text
    end

    it "offers to take the tour while it has not been completed" do
      sign_in_as(user)

      get seller_root_path

      expect(tour_button_label).to eq("Fazer o tour")
    end

    it "offers to redo the tour once completed" do
      seller.update!(tour_completed_at: Time.current)
      sign_in_as(user)

      get seller_root_path

      expect(tour_button_label).to eq("Refazer o tour")
    end
  end

  it "offers a button to take the tour again on the getting started page" do
    seller.update!(tour_completed_at: Time.current)
    sign_in_as(user)

    get seller_getting_started_path

    expect(Nokogiri::HTML(response.body).at_css("button[data-action='tour#start']")&.text).to eq("Fazer tour pelo painel")
  end

  describe "POST /painel/tour/concluir" do
    it "records the completion for the signed-in seller only" do
      other_seller
      sign_in_as(user)

      post seller_tour_completion_path

      expect(response).to have_http_status(:no_content)
      expect(seller.reload.tour_completed_at).to be_present
      expect(other_seller.reload.tour_completed_at).to be_nil
    end

    it "is idempotent and keeps the original completion time" do
      original = 3.days.ago.change(usec: 0)
      seller.update!(tour_completed_at: original)
      sign_in_as(user)

      post seller_tour_completion_path

      expect(response).to have_http_status(:no_content)
      expect(seller.reload.tour_completed_at).to eq(original)
    end

    it "redirects unauthenticated visitors to the seller login" do
      post seller_tour_completion_path

      expect(response).to redirect_to(seller_login_path)
    end
  end
end
