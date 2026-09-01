module Admin
  class ProductsController < BaseController
    include ProductGalleryUploads

    before_action :set_product, only: %i[show edit update publish unpublish discontinue]

    def index
      @products = Product.includes(:seller, :category, :main_image_attachment).order(created_at: :desc)
    end

    def show
    end

    def new
      @product = Product.new(seller: Seller.approved.first)
    end

    def create
      @product = Product.new(product_params)

      if @product.save
        sync_taxonomies
        if attach_images
          redirect_to admin_product_path(@product), notice: "Produto criado com sucesso."
        else
          redirect_to admin_product_path(@product), alert: images_error_message
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product.update(product_params)
        sync_taxonomies
        if attach_images
          redirect_to admin_product_path(@product), notice: "Produto atualizado com sucesso."
        else
          redirect_to admin_product_path(@product), alert: images_error_message
        end
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
      params.expect(product: [
        :name, :description, :price_cents, :currency, :sku, :stock_quantity, :main_image,
        :availability_type, :production_time_min_days, :production_time_max_days, :category_id, :seller_id,
        :weight_grams, :length_cm, :width_cm, :height_cm,
        :tag_names, :material_names, :technique_names, images: []
      ]).except(:tag_names, :material_names, :technique_names, :images)
    end

    def sync_taxonomies
      @product.tags = taxonomy_records(Tag, params.dig(:product, :tag_names))
      @product.materials = taxonomy_records(Material, params.dig(:product, :material_names))
      @product.techniques = taxonomy_records(Technique, params.dig(:product, :technique_names))
    end

    def taxonomy_records(model, names)
      Array(names).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?).uniq(&:downcase).map do |name|
        model.find_or_create_by!(name: name)
      end
    end
  end
end
