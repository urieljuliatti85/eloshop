module Admin
  class PersonalizationOptionsController < BaseController
    before_action :set_product
    before_action :set_personalization_option, only: %i[edit update destroy]

    def new
      @personalization_option = @product.personalization_options.new
    end

    def create
      @personalization_option = @product.personalization_options.new(personalization_option_params)

      if @personalization_option.save
        redirect_to admin_product_path(@product), notice: "Campo de personalização criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @personalization_option.update(personalization_option_params)
        redirect_to admin_product_path(@product), notice: "Campo de personalização atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @personalization_option.destroy
      redirect_to admin_product_path(@product), notice: "Campo de personalização removido."
    end

    private

    def set_product
      @product = Product.find_by!(slug: params[:product_id])
    end

    def set_personalization_option
      @personalization_option = @product.personalization_options.find(params[:id])
    end

    def personalization_option_params
      params.expect(personalization_option: %i[label required max_length])
    end
  end
end
