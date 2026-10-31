require "rails_helper"

RSpec.describe "Admin audit logs", type: :request do
  let(:admin) { User.create!(email_address: "admin-auditoria@eloshop.test", password: "password123") }
  let(:seller) { Seller.create!(name: "Ateliê Auditado", owner_full_name: "Dona Audit", cpf: "12000010601") }

  it "lists who changed what, with the author's e-mail and the field changes" do
    sign_in_as(admin)
    PaperTrail.request(whodunnit: admin.id.to_s) { seller.hide! }

    get admin_audit_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Artesão ##{seller.id}", "Ateliê Auditado", admin.email_address, "hidden_at")
  end

  it "shows changes made without a user as 'Sistema'" do
    sign_in_as(admin)
    PaperTrail.request(whodunnit: nil) { seller.hide! }

    get admin_audit_logs_path

    expect(response.body).to include("Sistema")
  end

  it "filters by type and ignores an unknown type" do
    sign_in_as(admin)
    seller.hide!

    get admin_audit_logs_path(type: "Coupon")
    expect(response.body).not_to include("Ateliê Auditado")

    get admin_audit_logs_path(type: "User")
    expect(response.body).to include("Ateliê Auditado")
  end

  it "never exposes seller tokens or the cpf" do
    sign_in_as(admin)
    seller.connect_mercado_pago!(Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "mp-audit", access_token: "segredo-access", refresh_token: "segredo-refresh",
      expires_at: 180.days.from_now, live_mode: true, test_account: false, public_key: "APP_USR-public"
    ))

    get admin_audit_logs_path

    expect(response.body).not_to match(/segredo-|ciphertext|12000010601/)
  end

  it "is closed to sellers and anonymous visitors" do
    get admin_audit_logs_path
    expect(response).to redirect_to(new_session_path)

    sign_in_as(User.create!(email_address: "ateliê@eloshop.test", password: "password123", role: :seller, seller: seller))
    get admin_audit_logs_path
    expect(response).to redirect_to(new_session_path)
  end
end
