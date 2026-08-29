module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update publish unpublish discontinue]

    def index
      @products = Product.order(created_at: :desc)
    end

    def show
    end

    def new
      @product = Product.new
    end

    def create
      @product = Product.new(product_params)

      if @product.save
        redirect_to admin_product_path(@product), notice: "Produto criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product.update(product_params)
        redirect_to admin_product_path(@product), notice: "Produto atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def publish
      @product.publish!
      redirect_to admin_product_path(@product), notice: "Produto publicado."
    rescue Product::InvalidStatusTransition => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    def unpublish
      @product.unpublish!
      redirect_to admin_product_path(@product), notice: "Produto despublicado."
    rescue Product::InvalidStatusTransition => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    def discontinue
      @product.discontinue!
      redirect_to admin_product_path(@product), notice: "Produto descontinuado."
    rescue Product::InvalidStatusTransition => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :description, :price_cents, :currency, :sku, :stock_quantity, :main_image ])
    end
  end
end
