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
end
