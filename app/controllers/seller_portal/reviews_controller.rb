module SellerPortal
  class ReviewsController < BaseController
    def index
      @reviews = Review.visible.where(product: current_seller.products).includes(:customer, :product).order(created_at: :desc)
    end

    def reply
      review = Review.visible.where(product: current_seller.products).find(params[:id])
      review.reply!(reply_params[:seller_reply])

      redirect_to seller_reviews_path, notice: "Resposta publicada."
    rescue ActiveRecord::RecordInvalid
      redirect_to seller_reviews_path, alert: "Escreva uma resposta antes de publicar."
    end

    private

    def reply_params
      params.expect(review: [ :seller_reply ])
    end
  end
end
