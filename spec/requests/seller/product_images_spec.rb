require "rails_helper"

RSpec.describe "Seller product images", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Imagens", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Imagens", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "images-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:product) { Product.create!(seller: seller, name: "Vaso", sku: "SELLER-IMG-001", price_cents: 5_000, stock_quantity: 3) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Prato", sku: "OTHER-IMG-001", price_cents: 4_000, stock_quantity: 2) }

  before do
    sign_in_as(user)
    product.images.attach(io: StringIO.new("own image"), filename: "own.png", content_type: "image/png")
    other_product.images.attach(io: StringIO.new("other image"), filename: "other.png", content_type: "image/png")
  end

  it "removes an image from an owned product" do
    attachment = product.images.attachments.first

    expect do
      delete seller_product_product_image_path(product, attachment)
    end.to change { product.images.reload.count }.by(-1)

    expect(response).to redirect_to(seller_product_path(product))
  end

  it "does not expose another seller product image" do
    attachment = other_product.images.attachments.first

    delete seller_product_product_image_path(other_product, attachment)

    expect(response).to have_http_status(:not_found)
    expect(other_product.images.reload.count).to eq(1)
  end

  it "does not remove an image from another product through an owned product URL" do
    attachment = other_product.images.attachments.first

    delete seller_product_product_image_path(product, attachment)

    expect(response).to have_http_status(:not_found)
    expect(other_product.images.reload.count).to eq(1)
  end
end
