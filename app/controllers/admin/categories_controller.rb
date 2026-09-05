module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]
    before_action :set_category_tree, only: %i[index new create edit update]

    def index
      @categories = @category_tree.categories
    end

    def new
      @category = Category.new
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        redirect_to admin_categories_path, notice: "Categoria criada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_categories_path, notice: "Categoria atualizada com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @category.destroy
        redirect_to admin_categories_path, notice: "Categoria removida."
      else
        redirect_to admin_categories_path, alert: @category.errors.full_messages.to_sentence
      end
    end

    private

    # A árvore inteira em uma leitura: a listagem e o seletor de pai renderizam
    # o breadcrumb de cada categoria, e `Category#breadcrumb_name` sobe a árvore
    # uma query por nível (ver Category::Tree).
    def set_category_tree
      @category_tree = Category::Tree.load
    end

    # Contagem por categoria em uma query, no lugar de `category.products.size`
    # por linha.
    def product_counts
      @product_counts ||= Product.group(:category_id).count
    end
    helper_method :product_counts

    # Categorias que não aparecem na loja: as desabilitadas e as que estão
    # sob uma desabilitada.
    def hidden_category_ids
      @hidden_category_ids ||= @category_tree.hidden_ids
    end
    helper_method :hidden_category_ids

    def set_category
      @category = Category.find_by!(slug: params[:id])
    end

    def category_params
      params.expect(category: %i[name parent_id active])
    end
  end
end
