# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller reviews", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Reviews", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Reviews", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "reviews-seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:customer) { Customer.create!(name: "Cliente review", email: "review-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:own_product) { Product.create!(seller: seller, name: "Peça própria", sku: "REVIEW-OWN-001", price_cents: 5_000, stock_quantity: 2) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Peça alheia", sku: "REVIEW-OTHER-001", price_cents: 5_000, stock_quantity: 2) }

  describe "GET /painel/reviews" do
    it "redirects unauthenticated visitors to the seller login" do
      get seller_reviews_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "lists only approved reviews of the seller's own products" do
      own_review = customer.reviews.create!(product: own_product, rating: 5, comment: "Ótimo produto")
      own_review.approve!
      other_review = customer.reviews.create!(product: other_product, rating: 4, comment: "Não é meu")
      other_review.approve!
      sign_in_as(user)

      get seller_reviews_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own_review.comment)
      expect(response.body).not_to include(other_review.comment)
    end

    it "does not list a pending review" do
      pending_review = customer.reviews.create!(product: own_product, rating: 5, comment: "Ainda não moderada")
      sign_in_as(user)

      get seller_reviews_path

      expect(response.body).not_to include(pending_review.comment)
    end
  end

  describe "PATCH /painel/reviews/:id/reply" do
    it "replies to an approved review of the seller's own product" do
      review = customer.reviews.create!(product: own_product, rating: 5, comment: "Ótimo produto")
      review.approve!
      sign_in_as(user)

      patch reply_seller_review_path(review), params: { review: { seller_reply: "Muito obrigado!" } }

      expect(response).to redirect_to(seller_reviews_path)
      expect(review.reload.seller_reply).to eq("Muito obrigado!")
    end

    it "does not allow replying with a blank text" do
      review = customer.reviews.create!(product: own_product, rating: 5, comment: "Ótimo produto")
      review.approve!
      sign_in_as(user)

      patch reply_seller_review_path(review), params: { review: { seller_reply: "" } }

      expect(response).to redirect_to(seller_reviews_path)
      expect(review.reload).not_to be_replied
    end

    it "does not allow replying to another seller's review" do
      review = customer.reviews.create!(product: other_product, rating: 5, comment: "Não é seu produto")
      review.approve!
      sign_in_as(user)

      patch reply_seller_review_path(review), params: { review: { seller_reply: "Tentativa indevida" } }

      expect(response).to have_http_status(:not_found)
      expect(review.reload).not_to be_replied
    end
  end
end
