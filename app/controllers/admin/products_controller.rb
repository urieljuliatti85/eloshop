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
      # O :id da rota recebe o slug, já que Product#to_param retorna o slug
      # (usado para gerar URLs amigáveis no storefront público — ver ProductsController).
      @product = Product.find_by!(slug: params[:id])
    end

    def product_params
      params.expect(product: [
        :name, :description, :price_cents, :currency, :sku, :stock_quantity, :main_image,
        :availability_type, :production_time_min_days, :production_time_max_days, :category_id,
        :tag_names, :material_names, :technique_names
      ]).except(:tag_names, :material_names, :technique_names)
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

    # Anexa (não substitui) as fotos novas enviadas — diferente do
    # main_image, a galeria precisa acumular ao longo de várias edições, e
    # cada foto é removida individualmente (ver Admin::ProductImagesController).
    # Validado antes de anexar: has_many_attached#attach não passa pelas
    # validações do Product (elas só disparam em save/valid?), então o
    # produto poderia ficar com uma imagem inválida anexada sem isso.
    def attach_images
      new_images = Array(params.dig(:product, :images)).reject(&:blank?)
      return true if new_images.empty?

      if @product.images.size + new_images.size > Product::IMAGES_MAX_COUNT
        @images_error = "não pode ter mais de #{Product::IMAGES_MAX_COUNT} imagens no total"
        return false
      end

      if new_images.any? { |file| !Product::MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(file.content_type) }
        @images_error = "deve conter apenas arquivos PNG, JPEG ou WEBP"
        return false
      end

      if new_images.any? { |file| file.size > Product::MAIN_IMAGE_MAX_BYTES }
        @images_error = "cada imagem deve ter no máximo 5MB"
        return false
      end

      @product.images.attach(new_images)
      true
    end

    def images_error_message
      "Produto salvo, mas as imagens não foram anexadas: #{@images_error}"
    end
  end
end
