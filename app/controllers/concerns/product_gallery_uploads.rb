module ProductGalleryUploads
  extend ActiveSupport::Concern

  included do
    before_action :optimize_uploaded_images, only: %i[create update]
  end

  private

  # Reduz as fotos antes de qualquer outra leitura dos parâmetros, para o
  # `Product` validar (5 MB) o arquivo já otimizado e não o original do
  # celular. Ver Images::Optimizer.
  def optimize_uploaded_images
    product_params = params[:product]
    return unless product_params.respond_to?(:key?)

    product_params[:main_image] = Images::Optimizer.call(product_params[:main_image]) if product_params[:main_image].respond_to?(:tempfile)
    return unless product_params[:images].is_a?(Array)

    product_params[:images] = product_params[:images].map { |file| file.respond_to?(:tempfile) ? Images::Optimizer.call(file) : file }
  end

  # A galeria acumula fotos ao longo das edições. Active Storage não executa
  # as validações do Product ao chamar attach, então validamos os novos
  # arquivos antes de persistir qualquer blob.
  def attach_images
    new_images = Array(params.dig(:product, :images)).reject(&:blank?)
    return true if new_images.empty?

    if @product.images.size + new_images.size > Product::IMAGES_MAX_COUNT
      @images_error = "não pode ter mais de #{Product::IMAGES_MAX_COUNT} imagens no total"
      return false
    end

    unless new_images.all? { |file| Product::MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(file.content_type) }
      @images_error = "deve conter apenas arquivos PNG, JPEG ou WEBP"
      return false
    end

    unless new_images.all? { |file| file.size <= Product::MAIN_IMAGE_MAX_BYTES }
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
