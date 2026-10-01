require "image_processing/vips"

module Images
  # Reduz a foto no envio, antes de ela ir para o Active Storage. O site guarda
  # o arquivo original inteiro, e foto de celular tem 2 a 5 MB: com 3 a 5
  # vendedores o volume de 500 MB da Railway enche, e foto acima de 5 MB era
  # recusada. Aqui o original é substituído por uma versão no máximo 2400 px de
  # lado, já girada pela orientação EXIF e sem metadados (localização incluída),
  # que continua grande para zoom e é uma fração do tamanho.
  #
  # Nunca quebra o cadastro: se a imagem não abrir, ou se a versão otimizada não
  # ficar menor, devolve o arquivo original, e as validações do Product decidem.
  class Optimizer
    MAX_DIMENSION = 2_400
    QUALITY = 85
    # Acima disto nem tentamos: o Product recusa de qualquer jeito.
    RAW_UPLOAD_MAX_BYTES = 20.megabytes
    FORMATS = { "image/jpeg" => "jpeg", "image/png" => "png", "image/webp" => "webp" }.freeze

    def self.call(upload)
      new(upload).call
    end

    def initialize(upload)
      @upload = upload
    end

    def call
      return @upload unless optimizable?

      optimized = process
      optimized && optimized.size < @upload.size ? optimized : @upload
    rescue StandardError => e
      Rails.event.notify("images.optimize_failed", error_class: e.class.name)
      @upload
    end

    private

    def optimizable?
      @upload.respond_to?(:tempfile) &&
        FORMATS.key?(@upload.content_type) &&
        @upload.size.between?(1, RAW_UPLOAD_MAX_BYTES)
    end

    def process
      format = target_format
      pipeline = ImageProcessing::Vips.source(@upload.tempfile.path).autorot.resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
      result = pipeline.convert(format).saver(strip: true, **saver_options(format)).call

      ActionDispatch::Http::UploadedFile.new(
        tempfile: result,
        filename: filename_for(format),
        type: FORMATS.key(format)
      )
    end

    # PNG sem transparência é quase sempre uma foto salva no formato errado:
    # vira JPEG. PNG com transparência (logotipo, recorte) segue PNG.
    def target_format
      source_format = FORMATS.fetch(@upload.content_type)
      return source_format unless source_format == "png"

      Vips::Image.new_from_file(@upload.tempfile.path).has_alpha? ? "png" : "jpeg"
    end

    def saver_options(format)
      format == "png" ? { compression: 9 } : { quality: QUALITY }
    end

    def filename_for(format)
      base = File.basename(@upload.original_filename.to_s, ".*").presence || "foto"
      "#{base}.#{format == 'jpeg' ? 'jpg' : format}"
    end
  end
end
