# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin seller reports", type: :request do
  let(:user) { User.create!(email_address: "reports-admin@example.com", password: "password", password_confirmation: "password") }
  let(:customer) { Customer.create!(name: "Cliente denúncia admin", email: "denuncia-admin@example.com", password: "password123") }
  let(:seller_report) { customer.seller_reports.create!(seller: approved_seller, reason: "fraud", details: "Não entregou") }

  describe "GET /admin/seller_reports" do
    it "redirects unauthenticated users" do
      get admin_seller_reports_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows admins to list reports" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      seller_report

      get admin_seller_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approved_seller.name)
    end

    it "filters reports by seller" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      other_seller = Seller.create!(name: "Outro ateliê denúncia #{SecureRandom.hex(3)}", owner_full_name: "Proprietário Teste", cpf: "50666667292", status: :approved, approved_at: Time.current)
      other_customer = Customer.create!(name: "Outro cliente seller filter", email: "outro-seller-filter@example.com", password: "password123")
      other_report = other_customer.seller_reports.create!(seller: other_seller, reason: "counterfeit")
      seller_report

      get admin_seller_reports_path(seller_id: approved_seller.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(seller_report.customer.name)
      expect(response.body).not_to include(other_report.customer.name)
    end

    it "filters reports by status" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      other_customer = Customer.create!(name: "Outro cliente", email: "outro-denuncia@example.com", password: "password123")
      resolved = other_customer.seller_reports.create!(seller: approved_seller, reason: "counterfeit", status: "resolved")

      get admin_seller_reports_path(status: "resolved")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(resolved.reason_label)
      expect(response.body).not_to include(seller_report.details)
    end
  end

  describe "PATCH /admin/seller_reports/:id/review" do
    it "marks a pending report as under review" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch review_admin_seller_report_path(seller_report)

      expect(response).to redirect_to(admin_seller_reports_path)
      expect(seller_report.reload).to be_reviewing
    end
  end

  describe "PATCH /admin/seller_reports/:id/resolve" do
    it "resolves a report" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch resolve_admin_seller_report_path(seller_report)

      expect(response).to redirect_to(admin_seller_reports_path)
      expect(seller_report.reload).to be_resolved
    end
  end

  describe "PATCH /admin/seller_reports/:id/dismiss" do
    it "dismisses a report" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch dismiss_admin_seller_report_path(seller_report)

      expect(response).to redirect_to(admin_seller_reports_path)
      expect(seller_report.reload).to be_dismissed
    end
  end
end
