# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Mercado Pago test accounts", type: :request do
  let(:user) { User.create!(email_address: "mp-test-admin@example.com", password: "password", password_confirmation: "password") }
  let!(:account) { MercadoPagoTestAccount.create!(account_type: "buyer", label: "Comprador BR", email: "buyer@testuser.com") }

  describe "GET /admin/contas-de-teste-mercado-pago" do
    it "redirects unauthenticated users to login" do
      get admin_mercado_pago_test_accounts_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists test accounts for authenticated admins" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_mercado_pago_test_accounts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comprador BR")
    end
  end

  describe "POST /admin/contas-de-teste-mercado-pago" do
    it "creates a test account with an encrypted password" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_mercado_pago_test_accounts_path, params: {
          mercado_pago_test_account: {
            account_type: "marketplace",
            label: "Marketplace principal",
            email: "marketplace@testuser.com",
            mercado_pago_user_id: "123456",
            username: "TESTUSER123456",
            password: "s3gredo",
            verification_code: "999999"
          }
        }
      end.to change(MercadoPagoTestAccount, :count).by(1)

      expect(response).to redirect_to(admin_mercado_pago_test_accounts_path)

      created = MercadoPagoTestAccount.find_by!(label: "Marketplace principal")
      expect(created.password).to eq("s3gredo")
      expect(created.password_ciphertext).not_to include("s3gredo")
    end

    it "rejects invalid params" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_mercado_pago_test_accounts_path, params: { mercado_pago_test_account: { account_type: "", label: "" } }
      end.not_to change(MercadoPagoTestAccount, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/contas-de-teste-mercado-pago/:id" do
    it "updates a test account" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch admin_mercado_pago_test_account_path(account), params: { mercado_pago_test_account: { label: "Comprador atualizado" } }

      expect(response).to redirect_to(admin_mercado_pago_test_accounts_path)
      expect(account.reload.label).to eq("Comprador atualizado")
    end
  end

  describe "DELETE /admin/contas-de-teste-mercado-pago/:id" do
    it "destroys a test account" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        delete admin_mercado_pago_test_account_path(account)
      end.to change(MercadoPagoTestAccount, :count).by(-1)

      expect(response).to redirect_to(admin_mercado_pago_test_accounts_path)
    end
  end
end
