require "test_helper"

class Admin::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @review = customers(:one).reviews.create!(product: products(:one), rating: 5, comment: "Ótimo")
  end

  test "redirects unauthenticated access to login" do
    get admin_reviews_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can list reviews" do
    sign_in_as(@user)

    get admin_reviews_path
    assert_response :success
  end

  test "filters reviews by status" do
    sign_in_as(@user)
    approved = customers(:two).reviews.create!(product: products(:one), rating: 4, comment: "Bom", status: "approved")

    get admin_reviews_path(status: "approved")

    assert_response :success
    assert_match approved.comment, response.body
    assert_no_match @review.comment, response.body
  end

  test "approves a pending review" do
    sign_in_as(@user)

    patch approve_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert @review.reload.approved?
  end

  test "rejects a pending review" do
    sign_in_as(@user)

    patch reject_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert @review.reload.rejected?
  end
end
