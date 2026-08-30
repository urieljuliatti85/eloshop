require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @customer = customers(:one)
  end

  def sign_in
    post customer_session_path, params: { email: @customer.email, password: "password123" }
  end

  test "redirects an unauthenticated visitor to customer login" do
    post product_reviews_path(@product), params: { review: { rating: 5, comment: "Ótimo" } }
    assert_redirected_to new_customer_session_path
  end

  test "creates a pending review for a logged in customer" do
    sign_in

    assert_difference("Review.count", 1) do
      post product_reviews_path(@product), params: { review: { rating: 5, comment: "Chegou rápido e bem embalado" } }
    end

    review = Review.last
    assert review.pending?
    assert_equal @customer, review.customer
    assert_redirected_to product_path(@product)
  end

  test "does not create a review with an invalid rating" do
    sign_in

    assert_no_difference("Review.count") do
      post product_reviews_path(@product), params: { review: { rating: 9, comment: "Ótimo" } }
    end

    assert_redirected_to product_path(@product)
  end

  test "does not let a customer review the same product twice" do
    sign_in
    @customer.reviews.create!(product: @product, rating: 4, comment: "Bom")

    assert_no_difference("Review.count") do
      post product_reviews_path(@product), params: { review: { rating: 5, comment: "De novo" } }
    end
  end

  test "a customer cannot set the status or verified_purchase directly" do
    sign_in

    post product_reviews_path(@product), params: { review: { rating: 5, comment: "Ótimo", status: "approved", verified_purchase: true } }

    review = Review.last
    assert review.pending?
    assert_not review.verified_purchase?
  end
end
