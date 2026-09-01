# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin reviews", type: :request do
  let(:user) { User.create!(email_address: "reviews-admin@example.com", password: "password", password_confirmation: "password") }
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso review admin", sku: "REV-ADMIN-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }
  let(:review) { customer.reviews.create!(product: product, rating: 5, comment: "Ótimo") }
  let(:customer) { Customer.create!(name: "Cliente review admin", email: "review-admin@example.com", password: "password123") }

  describe "GET /admin/reviews" do
    it "redirects unauthenticated users" do
      get admin_reviews_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows admins to list reviews" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_reviews_path

      expect(response).to have_http_status(:ok)
    end

    it "filters reviews by status" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      other_product = Product.create!(seller: approved_seller, name: "Cesto review admin", sku: "REV-ADMIN-002", price_cents: 5_990, stock_quantity: 3, currency: "BRL", status: :active)
      approved = customer.reviews.create!(product: other_product, rating: 4, comment: "Bom", status: "approved")

      get admin_reviews_path(status: "approved")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approved.comment)
      expect(response.body).not_to include(review.comment)
    end
  end

  describe "PATCH /admin/reviews/:id/approve" do
    it "approves a pending review" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch approve_admin_review_path(review)

      expect(response).to redirect_to(admin_reviews_path)
      expect(review.reload).to be_approved
    end
  end

  describe "PATCH /admin/reviews/:id/reject" do
    it "rejects a pending review" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch reject_admin_review_path(review)

      expect(response).to redirect_to(admin_reviews_path)
      expect(review.reload).to be_rejected
    end
  end
end
