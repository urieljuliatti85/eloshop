# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:customer) { Customer.create!(name: "Cliente notificações", email: "notif@example.com", password: "password123") }
  let(:other_customer) { Customer.create!(name: "Outro cliente", email: "other-notif@example.com", password: "password123") }

  def sign_in(customer)
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  describe "GET /notifications" do
    it "redirects unauthenticated visitors to customer login" do
      get notifications_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "lists only the authenticated customer's notifications" do
      own = Notification.create!(recipient: customer, kind: :order_confirmed, title: "Pagamento confirmado", body: "Seu pedido foi confirmado.")
      Notification.create!(recipient: other_customer, kind: :order_confirmed, title: "Outro pedido", body: "Não é seu.")
      sign_in(customer)

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own.title)
      expect(response.body).not_to include("Outro pedido")
    end
  end

  describe "PATCH /notifications/:id/mark_as_read" do
    it "marks the notification as read and redirects to its url" do
      notification = Notification.create!(recipient: customer, kind: :new_message, title: "Nova mensagem", body: "Você recebeu uma mensagem.", url: "/orders/1")
      sign_in(customer)

      patch mark_as_read_notification_path(notification)

      expect(notification.reload).to be_read
      expect(response).to redirect_to("/orders/1")
    end

    it "does not allow marking another customer's notification as read" do
      notification = Notification.create!(recipient: other_customer, kind: :new_message, title: "Nova mensagem", body: "Não é sua.")
      sign_in(customer)

      patch mark_as_read_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(notification.reload).not_to be_read
    end
  end
end
