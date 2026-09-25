# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin notifications", type: :request do
  let(:user) { User.create!(email_address: "notif-admin@example.com", password: "password", password_confirmation: "password") }
  let(:other_user) { User.create!(email_address: "other-notif-admin@example.com", password: "password", password_confirmation: "password") }

  describe "GET /admin/notifications" do
    it "redirects unauthenticated users" do
      get admin_notifications_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists only the authenticated admin's notifications" do
      own = Notification.create!(recipient: user, kind: :seller_report_received, title: "Nova denúncia", body: "Um ateliê foi denunciado.")
      Notification.create!(recipient: other_user, kind: :seller_report_received, title: "Outra denúncia", body: "Não é sua.")
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own.title)
      expect(response.body).not_to include("Outra denúncia")
    end
  end

  describe "PATCH /admin/notifications/:id/mark_as_read" do
    it "marks the notification as read and redirects to its url" do
      notification = Notification.create!(recipient: user, kind: :payment_declined, title: "Pagamento recusado", body: "Um pagamento foi recusado.", url: "/admin/orders/1")
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch mark_as_read_admin_notification_path(notification)

      expect(notification.reload).to be_read
      expect(response).to redirect_to("/admin/orders/1")
    end

    it "does not allow marking another admin's notification as read" do
      notification = Notification.create!(recipient: other_user, kind: :payment_declined, title: "Pagamento recusado", body: "Não é sua.")
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch mark_as_read_admin_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(notification.reload).not_to be_read
    end
  end
end
