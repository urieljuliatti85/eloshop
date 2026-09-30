require "rails_helper"

RSpec.describe "Admin fraud alerts", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Alerta", owner_full_name: "Dona Alerta", cpf: "12000010601") }
  let(:admin) { User.create!(email_address: "admin-fraude@eloshop.test", password: "password123") }
  let!(:alert) { FraudAlert.create!(seller: seller, rule: "unverified_account", detected_at: Time.current) }

  it "shows open alerts on the seller page" do
    sign_in_as(admin)

    get admin_seller_path(seller)

    expect(response.body).to include("Alertas de fraude abertos", alert.title, "Marcar como resolvido")
  end

  it "resolves an alert, idempotently, and hides it from the page" do
    sign_in_as(admin)

    2.times { patch resolve_admin_fraud_alert_path(alert) }
    get admin_seller_path(seller)

    expect(alert.reload).to be_resolved
    expect(response.body).not_to include("Alertas de fraude abertos")
  end

  it "does not let a seller resolve an alert" do
    seller_user = User.create!(email_address: "vendedor-fraude@eloshop.test", password: "password123", role: :seller, seller: seller)
    sign_in_as(seller_user)

    patch resolve_admin_fraud_alert_path(alert)

    expect(alert.reload).not_to be_resolved
  end

  describe "GET /admin/fraudes" do
    let!(:resolved) do
      FraudAlert.create!(seller: seller, rule: "self_purchase", detail: { "order_ids" => [ 42 ] },
        detected_at: 2.days.ago, resolved_at: 1.day.ago)
    end

    it "redirects a visitor to the login" do
      get admin_fraud_alerts_path

      expect(response).to redirect_to(new_session_path)
    end

    it "keeps a seller out" do
      sign_in_as(User.create!(email_address: "vendedor-fraudes@eloshop.test", password: "password123", role: :seller, seller: seller))

      get admin_fraud_alerts_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists open alerts by default, with the monitored rules and a nav link" do
      sign_in_as(admin)

      get admin_fraud_alerts_path

      expect(response.body).to include("Fraudes", "Ateliê Alerta", alert.title, "O que é monitorado", admin_fraud_alerts_path)
      expect(response.body).not_to include("##{42}")
    end

    it "shows resolved alerts with their orders when filtered" do
      sign_in_as(admin)

      get admin_fraud_alerts_path(status: "resolved")

      expect(response.body).to include("#42", "Resolvido em")
      expect(response.body).not_to include("Marcar como resolvido")
    end

    it "filters by rule and ignores an unknown rule" do
      sign_in_as(admin)

      get admin_fraud_alerts_path(status: "all", rule: "self_purchase")
      expect(response.body).to include("#42")

      get admin_fraud_alerts_path(status: "all", rule: "nao-existe")
      expect(response).to have_http_status(:ok)
    end

    it "shows an all-clear message when nothing is open" do
      alert.resolve!
      sign_in_as(admin)

      get admin_fraud_alerts_path

      expect(response.body).to include("Nenhum alerta aberto")
    end
  end
end
