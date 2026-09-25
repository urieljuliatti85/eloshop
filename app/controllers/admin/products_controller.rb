module Admin
  class ProductsController < BaseController
    include ProductGalleryUploads

    before_action :set_product, only: %i[show edit update publish unpublish discontinue]
    before_action :set_category_tree, only: %i[new create edit update]

    SORTABLE_COLUMNS = {
      "name" => "products.name",
      "seller" => "sellers.name",
      "sku" => "products.sku",
      "price" => "products.price_cents",
      "stock" => "products.stock_quantity",
      "status" => "products.status"
    }.freeze

    def index
      # `joins(:seller)` só para permitir ordenar/filtrar por `sellers.name` —
      # `category`/`main_image_attachment` vão por `preload` (não entram no
      # ORDER BY) para não repetir o LEFT JOIN inflando o custo estimado do
      # plano, como já aconteceu no catálogo público (CLAUDE.md, Fase 17).
      products = Product.joins(:seller).preload(:seller, :category, :main_image_attachment)
      products = apply_filters(products)
      products = products.order(sort_clause)

      @sellers = Seller.order(:name)
      @products = paginate(products)
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

    def sort_clause
      column = SORTABLE_COLUMNS.fetch(params[:sort], "products.created_at")
      direction = params[:direction] == "asc" ? "asc" : "desc"
      "#{column} #{direction}, products.id #{direction}"
    end

    def apply_filters(products)
      products = products.where("products.name ILIKE :term OR products.sku ILIKE :term", term: "%#{params[:query]}%") if params[:query].present?
      products = products.where(seller_id: params[:seller_id]) if params[:seller_id].present?
      products = products.where(status: params[:status]) if params[:status].present? && Product.statuses.key?(params[:status])
      products = products.where(price_cents: price_range) if price_range
      products = products.where(stock_quantity: stock_range) if stock_range
      products
    end

    # `nil` quando nenhum dos dois limites foi informado — filtro não se
    # aplica. `..` sem limite de um lado deixa o outro em aberto.
    def price_range
      min = reais_to_cents(params[:price_min])
      max = reais_to_cents(params[:price_max])
      return nil if min.nil? && max.nil?

      (min || 0)..(max || Float::INFINITY)
    end

    def stock_range
      min = Integer(params[:stock_min], exception: false)
      max = Integer(params[:stock_max], exception: false)
      return nil if min.nil? && max.nil?

      (min || 0)..(max || Float::INFINITY)
    end

    def reais_to_cents(value)
      return nil if value.blank?

      (BigDecimal(value.to_s.tr(",", ".")) * 100).round.to_i
    rescue ArgumentError
      nil
    end

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
