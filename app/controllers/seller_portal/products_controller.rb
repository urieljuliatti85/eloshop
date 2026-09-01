module SellerPortal
  class ProductsController < BaseController
    include ProductGalleryUploads

    before_action :set_product, only: %i[show edit update publish unpublish discontinue]
    before_action :set_category_tree, only: %i[new create edit update]

    def index
      @products = current_seller.products.includes(:category).order(created_at: :desc)
      @products = @products.matching_query(params[:q]) if params[:q].present?
    end

    def show
    end

    def new
      @product = current_seller.products.new
    end

    def create
      @product = current_seller.products.new(product_params)
      if @product.save
        if attach_images
          redirect_to seller_product_path(@product), notice: "Produto criado com sucesso."
        else
          redirect_to seller_product_path(@product), alert: images_error_message
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product.update(product_params)
        if attach_images
          redirect_to seller_product_path(@product), notice: "Produto atualizado com sucesso."
        else
          redirect_to seller_product_path(@product), alert: images_error_message
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def publish
      @product.publish!
      redirect_to seller_product_path(@product), notice: "Produto publicado."
    rescue Product::InvalidStatusTransition => e
      redirect_to seller_product_path(@product), alert: e.message
    end

    def unpublish
      @product.unpublish!
      redirect_to seller_product_path(@product), notice: "Produto despublicado."
    rescue Product::InvalidStatusTransition => e
      redirect_to seller_product_path(@product), alert: e.message
    end

    def discontinue
      @product.discontinue!
      redirect_to seller_product_path(@product), notice: "Produto descontinuado."
    rescue Product::InvalidStatusTransition => e
      redirect_to seller_product_path(@product), alert: e.message
    end

    private

    # O seletor de categoria renderiza o breadcrumb de cada opção; sem a árvore
    # carregada, cada uma sobe a hierarquia com uma query por nível.
    def set_category_tree
      @category_tree = Category::Tree.load
    end

    def set_product
      @product = current_seller.products.find(params[:id])
    end

    def product_params
      params.expect(product: [
        :name, :description, :price_cents, :currency, :sku, :stock_quantity, :main_image,
        :availability_type, :production_time_min_days, :production_time_max_days, :category_id,
        :weight_grams, :length_cm, :width_cm, :height_cm, images: []
      ]).except(:images)
    end
  end
end
