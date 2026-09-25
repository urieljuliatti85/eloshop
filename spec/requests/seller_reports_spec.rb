# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller reports", type: :request do
  let(:customer) { Customer.create!(name: "Cliente denúncia", email: "denuncia@example.com", password: "password123") }
  let(:admin) { User.create!(email_address: "admin-denuncia@example.com", password: "password", password_confirmation: "password") }

  describe "POST /artesaos/:seller_slug/denuncias" do
    it "redirects unauthenticated visitors to customer login" do
      post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "fraud" } }

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "creates a pending report for a logged in customer" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "fraud", details: "Cobrou e não entregou" } }
      end.to change(SellerReport, :count).by(1)

      report = SellerReport.last
      expect(report).to be_pending
      expect(report.customer).to eq(customer)
      expect(report.seller).to eq(approved_seller)
      expect(response).to redirect_to(seller_path(approved_seller.slug))
    end

    it "notifies platform admins when a report is created" do
      admin
      post customer_session_path, params: { email: customer.email, password: "password123" }

      post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "fraud" } }

      notification = admin.notifications.seller_report_received.last
      expect(notification).to be_present
      expect(notification.body).to include(approved_seller.name)
    end

    it "rejects a reason outside the allowed list" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "not-a-real-reason" } }
      end.not_to change(SellerReport, :count)

      expect(response).to redirect_to(seller_path(approved_seller.slug))
    end

    it "prevents a customer from reporting the same atelier twice" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      customer.seller_reports.create!(seller: approved_seller, reason: "fraud")

      expect do
        post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "counterfeit" } }
      end.not_to change(SellerReport, :count)
    end

    it "ignores attempts to set status directly" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      post seller_seller_reports_path(approved_seller.slug), params: { seller_report: { reason: "fraud", status: "resolved" } }

      expect(SellerReport.last).to be_pending
    end

    it "returns 404 for an atelier that is not approved" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      pending_seller = Seller.create!(name: "Ateliê pendente denúncia #{SecureRandom.hex(3)}", owner_full_name: "Proprietário Teste", cpf: "50444445706", status: :pending)

      post seller_seller_reports_path(pending_seller.slug), params: { seller_report: { reason: "fraud" } }

      expect(response).to have_http_status(:not_found)
    end
  end
end
