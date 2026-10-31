require "test_helper"

module Images
  class OptimizerTest < ActiveSupport::TestCase
    # Ruído puro não comprime: dá um JPEG pesado como o de um celular.
    def noise_image(width, height, bands: 3)
      image = Vips::Image.gaussnoise(width, height, sigma: 55, mean: 128).cast(:uchar)
      bands == 3 ? image.bandjoin([ image, image ]) : image
    end

    def upload_for(image, ext:, type:, orientation: nil, **saver)
      file = Tempfile.new([ "foto", ".#{ext}" ])
      file.binmode
      image = image.copy.tap { |i| i.set_type(GObject::GINT_TYPE, "orientation", orientation) } if orientation
      image.write_to_file(file.path, **saver)
      ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "foto.#{ext}", type: type)
    end

    def dimensions(upload)
      image = Vips::Image.new_from_file(upload.tempfile.path)
      [ image.width, image.height ]
    end

    test "shrinks a big phone photo to at most 2400 px on the long side and far fewer bytes, keeping JPEG" do
      original = upload_for(noise_image(3600, 2400), ext: "jpg", type: "image/jpeg", Q: 95)

      result = Optimizer.call(original)

      assert_not_same original, result
      assert_equal "image/jpeg", result.content_type
      assert_equal "foto.jpg", result.original_filename
      assert_operator dimensions(result).max, :<=, Optimizer::MAX_DIMENSION
      assert_operator result.size, :<, original.size / 2
    end

    test "applies the EXIF orientation, so a rotated phone photo is not stored sideways" do
      original = upload_for(noise_image(3000, 2000), ext: "jpg", type: "image/jpeg", orientation: 6, Q: 90)

      width, height = dimensions(Optimizer.call(original))

      assert_operator height, :>, width
    end

    test "turns an opaque PNG into a JPEG, but keeps a PNG that has transparency" do
      opaque = upload_for(noise_image(2000, 1500), ext: "png", type: "image/png")
      transparent = upload_for(noise_image(2000, 1500).bandjoin(255), ext: "png", type: "image/png")

      jpeg = Optimizer.call(opaque)
      png = Optimizer.call(transparent)

      assert_equal "image/jpeg", jpeg.content_type
      assert_equal "foto.jpg", jpeg.original_filename
      assert_equal "image/png", png.content_type
    end

    test "returns the very same upload when the result would not be smaller" do
      tiny = upload_for(noise_image(200, 150), ext: "jpg", type: "image/jpeg", Q: 40)

      assert_same tiny, Optimizer.call(tiny)
    end

    test "never raises: a broken image or an unsupported type comes back untouched" do
      broken = Tempfile.new([ "quebrada", ".jpg" ]).tap { |f| f.write("isto não é uma imagem"); f.flush }
      broken_upload = ActionDispatch::Http::UploadedFile.new(tempfile: broken, filename: "quebrada.jpg", type: "image/jpeg")
      gif = ActionDispatch::Http::UploadedFile.new(tempfile: Tempfile.new([ "a", ".gif" ]), filename: "a.gif", type: "image/gif")

      assert_same broken_upload, Optimizer.call(broken_upload)
      assert_same gif, Optimizer.call(gif)
    end

    test "does not even try above the raw upload limit" do
      huge = Struct.new(:tempfile, :content_type, :size).new(Tempfile.new("x"), "image/jpeg", Optimizer::RAW_UPLOAD_MAX_BYTES + 1)

      assert_same huge, Optimizer.call(huge)
    end
  end
end
