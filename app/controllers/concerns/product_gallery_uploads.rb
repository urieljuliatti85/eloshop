module ProductGalleryUploads
  extend ActiveSupport::Concern

  private

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
