require "rails_helper"

RSpec.describe "Seller personalization options", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Personalizações", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Personalizações", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "personalizations-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:product) { Product.create!(seller: seller, name: "Caneca", sku: "SELLER-PER-001", price_cents: 5_000, stock_quantity: 3) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Quadro", sku: "OTHER-PER-001", price_cents: 7_000, stock_quantity: 2) }
  let(:option) { product.personalization_options.create!(label: "Nome gravado", required: true, max_length: 20) }

  before { sign_in_as(user) }

  it "renders the personalization form for an owned product" do
    get new_seller_product_personalization_option_path(product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nova personalização", "Salvar personalização")
  end

  it "creates a personalization field for an owned product" do
    expect do
      post seller_product_personalization_options_path(product), params: {
        personalization_option: { label: "Mensagem", required: false, max_length: 80 }
      }
    end.to change(product.personalization_options, :count).by(1)

    expect(response).to redirect_to(seller_product_path(product))
  end

  it "does not expose another seller product" do
    post seller_product_personalization_options_path(other_product), params: {
      personalization_option: { label: "Intrusão", required: false, max_length: 20 }
    }

    expect(response).to have_http_status(:not_found)
  end

  it "does not accept an option belonging to another product in the nested URL" do
    other_option = other_product.personalization_options.create!(label: "Cor", required: false, max_length: 20)

    patch seller_product_personalization_option_path(product, other_option), params: { personalization_option: { max_length: 99 } }

    expect(response).to have_http_status(:not_found)
    expect(other_option.reload.max_length).to eq(20)
  end

  it "updates an owned personalization field" do
    patch seller_product_personalization_option_path(product, option), params: { personalization_option: { max_length: 40 } }

    expect(response).to redirect_to(seller_product_path(product))
    expect(option.reload.max_length).to eq(40)
  end
end
