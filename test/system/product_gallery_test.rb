require "application_system_test_case"

class ProductGalleryTest < ApplicationSystemTestCase
  test "clicking a thumbnail swaps the main image" do
    product = products(:one)
    product.main_image.attach(io: File.open(file_fixture("sample.png")), filename: "cover.png", content_type: "image/png")
    product.images.attach(io: File.open(file_fixture("sample.png")), filename: "extra.png", content_type: "image/png")

    visit product_path(product.seller, product.slug)

    main_image = find("[data-gallery-target='main']")
    initial_src = main_image[:src]

    all("button[data-action='gallery#show']").last.click

    assert_not_equal initial_src, find("[data-gallery-target='main']")[:src]
  end
end
