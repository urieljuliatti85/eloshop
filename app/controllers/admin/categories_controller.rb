module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = Category.order(:name).includes(:parent, :products)
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

    def set_category
      @category = Category.find_by!(slug: params[:id])
    end

    def category_params
      params.expect(category: %i[name parent_id])
    end
  end
end
