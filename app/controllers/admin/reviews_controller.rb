module Admin
  class ReviewsController < BaseController
    before_action :set_review, only: %i[approve reject]

    def index
      @reviews = Review.includes(:product, :customer).order(created_at: :desc)
      @reviews = @reviews.where(status: params[:status]) if params[:status].present?
    end

    def approve
      @review.approve!
      Notification.create!(
        recipient: @review.product.seller,
        kind: :new_review,
        title: "Nova avaliação",
        body: "Seu produto \"#{@review.product.name}\" recebeu uma nova avaliação.",
        url: seller_product_path(@review.product)
      )
      redirect_to admin_reviews_path, notice: "Avaliação aprovada."
    end

    def reject
      @review.reject!
      redirect_to admin_reviews_path, notice: "Avaliação rejeitada."
    end

    private

    def set_review
      @review = Review.find(params[:id])
    end
  end
end
