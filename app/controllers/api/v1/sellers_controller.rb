module Api
  module V1
    class SellersController < BaseController
      # Só ateliês que aparecem na loja (`Seller.publicly_listed`) e com peça publicada, o mesmo critério da vitrine
      # pública: listar um vendedor cuja página devolve lista vazia é um beco.
      def index
        @sellers = Seller.publicly_listed
          .where(id: Product.publicly_visible.select(:seller_id))
          .order(:name)
        @product_counts = Product.publicly_visible.group(:seller_id).count
      end

      def show
        @seller = Seller.publicly_listed.find_by!(slug: params[:slug])
        @product_count = @seller.products.publicly_visible.count
      end
    end
  end
end
