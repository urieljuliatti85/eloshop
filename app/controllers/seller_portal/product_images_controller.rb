module SellerPortal
  class ProductImagesController < BaseController
    before_action :set_product

    def destroy
      @product.images.attachments.find(params[:id]).purge
      redirect_to seller_product_path(@product), notice: "Imagem removida."
    end

    private

    def set_product
      @product = current_seller.products.find(params[:product_id])
    end
  end
end
