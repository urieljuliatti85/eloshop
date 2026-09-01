class ReviewsController < StorefrontController
  before_action :set_product

  def create
    @review = @product.reviews.new(review_params)
    @review.customer = Current.customer

    if @review.save
      redirect_to product_path(@product.seller, @product.slug), notice: "Obrigado! Sua avaliação foi enviada e será exibida após aprovação."
    else
      redirect_to product_path(@product.seller, @product.slug), alert: @review.errors.full_messages.to_sentence
    end
  end

  private

  def set_product
    seller = Seller.approved.find_by!(slug: params[:seller_slug])
    @product = seller.products.publicly_visible.find_by!(slug: params[:product_slug])
  end

  def review_params
    params.expect(review: %i[rating comment])
  end
end
