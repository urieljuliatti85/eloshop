# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller notifications", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Notificações", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Notificações", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "notif-seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }

  describe "GET /painel/notifications" do
    it "redirects unauthenticated visitors to the seller login" do
      get seller_notifications_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "lists only the authenticated seller's notifications" do
      own = Notification.create!(recipient: seller, kind: :order_confirmed, title: "Nova venda", body: "Você tem um novo pedido.")
      Notification.create!(recipient: other_seller, kind: :order_confirmed, title: "Outra venda", body: "Não é sua.")
      sign_in_as(user)

      get seller_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own.title)
      expect(response.body).not_to include("Outra venda")
    end
  end

  describe "PATCH /painel/notifications/:id/mark_as_read" do
    it "marks the notification as read and redirects to its url" do
      notification = Notification.create!(recipient: seller, kind: :new_review, title: "Nova avaliação", body: "Você recebeu uma avaliação.", url: "/painel/products/1")
      sign_in_as(user)

      patch mark_as_read_seller_notification_path(notification)

      expect(notification.reload).to be_read
      expect(response).to redirect_to("/painel/products/1")
    end

    it "does not allow marking another seller's notification as read" do
      notification = Notification.create!(recipient: other_seller, kind: :new_review, title: "Nova avaliação", body: "Não é sua.")
      sign_in_as(user)

      patch mark_as_read_seller_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(notification.reload).not_to be_read
    end
  end
end
