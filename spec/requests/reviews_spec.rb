# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reviews", type: :request do
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso review", sku: "REV-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }
  let(:customer) { Customer.create!(name: "Cliente review", email: "review@example.com", password: "password123") }

  describe "POST /products/:product_id/reviews" do
    it "redirects unauthenticated visitors to customer login" do
      post product_reviews_path(product.seller, product.slug), params: { review: { rating: 5, comment: "Ótimo" } }

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "creates a pending review for a logged in customer" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post product_reviews_path(product.seller, product.slug), params: { review: { rating: 5, comment: "Chegou rápido e bem embalado" } }
      end.to change(Review, :count).by(1)

      review = Review.last
      expect(review).to be_pending
      expect(review.customer).to eq(customer)
      expect(response).to redirect_to(product_path(product.seller, product.slug))
    end

    it "rejects invalid ratings" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post product_reviews_path(product.seller, product.slug), params: { review: { rating: 9, comment: "Ótimo" } }
      end.not_to change(Review, :count)

      expect(response).to redirect_to(product_path(product.seller, product.slug))
    end

    it "prevents duplicate reviews for the same product" do
      post customer_session_path, params: { email: customer.email, password: "password123" }
      customer.reviews.create!(product: product, rating: 4, comment: "Bom")

      expect do
        post product_reviews_path(product.seller, product.slug), params: { review: { rating: 5, comment: "De novo" } }
      end.not_to change(Review, :count)
    end

    it "ignores attempts to set status and verified_purchase directly" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      post product_reviews_path(product.seller, product.slug), params: {
        review: { rating: 5, comment: "Ótimo", status: "approved", verified_purchase: true }
      }

      review = Review.last
      expect(review).to be_pending
      expect(review).not_to be_verified_purchase
    end
  end
end
