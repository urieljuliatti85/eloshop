require "rails_helper"

RSpec.describe "Seller product variants", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Variantes", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Variantes", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "variants-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:product) { Product.create!(seller: seller, name: "Camiseta", sku: "SELLER-VAR-001", price_cents: 8_000, stock_quantity: 3) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Bolsa", sku: "OTHER-VAR-001", price_cents: 9_000, stock_quantity: 2) }
  let(:variant) { product.product_variants.create!(sku: "SELLER-VAR-M", price_cents: 8_000, stock_quantity: 2, size: "M") }

  before { sign_in_as(user) }

  it "renders the variant form for an owned product" do
    get new_seller_product_product_variant_path(product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nova variante", "Salvar variante")
  end

  it "creates a variant for an owned product" do
    expect do
      post seller_product_product_variants_path(product), params: {
        product_variant: { sku: "SELLER-VAR-G", price_cents: 8_500, stock_quantity: 4, size: "G", active: true }
      }
    end.to change(product.product_variants, :count).by(1)

    expect(response).to redirect_to(seller_product_path(product))
  end

  it "does not expose another seller product" do
    post seller_product_product_variants_path(other_product), params: {
      product_variant: { sku: "INTRUSION-VAR", price_cents: 1_000, stock_quantity: 1, size: "P" }
    }

    expect(response).to have_http_status(:not_found)
  end

  it "does not accept a variant belonging to another product in the nested URL" do
    other_variant = other_product.product_variants.create!(sku: "OTHER-VAR-M", price_cents: 9_000, stock_quantity: 1, size: "M")

    patch seller_product_product_variant_path(product, other_variant), params: { product_variant: { stock_quantity: 99 } }

    expect(response).to have_http_status(:not_found)
    expect(other_variant.reload.stock_quantity).to eq(1)
  end

  it "updates an owned variant" do
    patch seller_product_product_variant_path(product, variant), params: { product_variant: { stock_quantity: 7 } }

    expect(response).to redirect_to(seller_product_path(product))
    expect(variant.reload.stock_quantity).to eq(7)
  end
end
