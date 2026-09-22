require "test_helper"

class SeoHelperTest < ActionView::TestCase
  include ERB::Util

  test "product_breadcrumb_structured_data lists home, shop and product in order" do
    product = products(:one)

    data = JSON.parse(product_breadcrumb_structured_data(product))

    assert_equal "BreadcrumbList", data["@type"]
    positions = data["itemListElement"].map { |item| item["position"] }
    assert_equal [ 1, 2, 3 ], positions
    assert_equal "Início", data["itemListElement"][0]["name"]
    assert_equal "Loja", data["itemListElement"][1]["name"]
    assert_equal product.name, data["itemListElement"][2]["name"]
    assert_equal product_url(product.seller, product.slug), data["itemListElement"][2]["item"]
  end

  test "og_image_dimensions returns nil when attachment has no image metadata yet" do
    product = products(:one)
    product.main_image.attach(
      io: StringIO.new("fake"),
      filename: "vaso.png",
      content_type: "image/png"
    )

    assert_nil og_image_dimensions(product.main_image)
  end

  test "og_image_dimensions returns nil for an attachment that is not attached" do
    product = products(:one)

    assert_nil og_image_dimensions(product.main_image)
  end

  test "og_image_dimensions returns width and height once analyzed" do
    product = products(:one)
    product.main_image.attach(
      io: StringIO.new("fake"),
      filename: "vaso.png",
      content_type: "image/png"
    )
    product.main_image.blob.update!(metadata: { width: 800, height: 600 })

    assert_equal([ 800, 600 ], og_image_dimensions(product.main_image))
  end
end
