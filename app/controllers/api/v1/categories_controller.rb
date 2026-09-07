module Api
  module V1
    class CategoriesController < BaseController
      # A árvore visível inteira em uma leitura. Categoria desabilitada (e a
      # subárvore abaixo dela) fica de fora, igual ao filtro do catálogo.
      def index
        @tree = Category::Tree.load
        @categories = @tree.visible
        @product_counts = Product.publicly_visible.group(:category_id).count
      end
    end
  end
end
