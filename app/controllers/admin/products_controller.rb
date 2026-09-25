module Admin
  class ProductsController < BaseController
    include ProductGalleryUploads

    before_action :set_product, only: %i[show edit update publish unpublish discontinue]
    before_action :set_category_tree, only: %i[new create edit update]

    def index
      @products = paginate(Product.includes(:seller, :category, :main_image_attachment).order(created_at: :desc))
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

    def bulk_discontinue
      products = Product.where(id: params[:product_ids])
      discontinued_count = 0

      products.find_each do |product|
        product.discontinue!
        discontinued_count += 1
      rescue Product::InvalidStatusTransition
        next
      end

      redirect_to admin_products_path, notice: bulk_discontinue_notice(discontinued_count, products.size)
    end

    def bulk_unpublish
      products = Product.where(id: params[:product_ids])
      unpublished_count = 0

      products.find_each do |product|
        product.unpublish!
        unpublished_count += 1
      rescue Product::InvalidStatusTransition
        next
      end

      redirect_to admin_products_path, notice: bulk_unpublish_notice(unpublished_count, products.size)
    end

    private

    def bulk_discontinue_notice(discontinued_count, selected_count)
      return "Nenhum produto selecionado." if selected_count.zero?

      skipped_count = selected_count - discontinued_count
      return "#{discontinued_count} produto(s) descontinuado(s)." if skipped_count.zero?

      "#{discontinued_count} produto(s) descontinuado(s). #{skipped_count} não puderam ser alterados (já descontinuados ou status incompatível)."
    end

    def bulk_unpublish_notice(unpublished_count, selected_count)
      return "Nenhum produto selecionado." if selected_count.zero?

      skipped_count = selected_count - unpublished_count
      return "#{unpublished_count} produto(s) escondido(s)." if skipped_count.zero?

      "#{unpublished_count} produto(s) escondido(s). #{skipped_count} não puderam ser alterados (já estavam fora de active)."
    end

    # O seletor de categoria renderiza o breadcrumb de cada opção; sem a árvore
    # carregada, cada uma sobe a hierarquia com uma query por nível.
    def set_category_tree
      @category_tree = Category::Tree.load
    end

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [
        :name, :description, :price, :currency, :sku, :stock_quantity, :main_image,
        :availability_type, :production_time_min_days, :production_time_max_days, :category_id, :seller_id,
        :weight_grams, :length_cm, :width_cm, :height_cm,
        :fixed_shipping, :fixed_shipping_estimated_days, :local_pickup_enabled, :free_shipping,
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
