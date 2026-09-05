module Admin
  class ProductVariantsController < BaseController
    before_action :set_product
    before_action :set_product_variant, only: %i[edit update destroy]

    def new
      @product_variant = @product.product_variants.new
    end

    def create
      @product_variant = @product.product_variants.new(product_variant_params)

      if @product_variant.save
        redirect_to admin_product_path(@product), notice: "Variante criada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product_variant.update(product_variant_params)
        redirect_to admin_product_path(@product), notice: "Variante atualizada com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      ActiveRecord::Base.transaction(requires_new: true) { @product_variant.destroy! }
      redirect_to admin_product_path(@product), notice: "Variante removida."
    rescue ActiveRecord::InvalidForeignKey
      redirect_to admin_product_path(@product), alert: "Esta variante já foi usada em pedidos e não pode ser excluída — desative-a em vez disso."
    end

    private

    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_product_variant
      @product_variant = @product.product_variants.find(params[:id])
    end

    def product_variant_params
      params.expect(product_variant: %i[sku price stock_quantity size color material active])
    end
  end
end
