module Admin
  class ProductImagesController < BaseController
    before_action :set_product

    def destroy
      @product.images.attachments.find(params[:id]).purge
      redirect_to admin_product_path(@product), notice: "Imagem removida."
    end

    private

    def set_product
      @product = Product.find(params[:product_id])
    end
  end
end
