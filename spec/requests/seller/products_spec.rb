require "rails_helper"

RSpec.describe "Seller products", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Um", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Ateliê Dois", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:own_product) { Product.create!(seller: seller, name: "Vaso próprio", sku: "OWN-001", price_cents: 5_000, stock_quantity: 2) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Vaso alheio", sku: "OTHER-001", price_cents: 5_000, stock_quantity: 2) }

  before { sign_in_as(user) }

  it "lists only the authenticated seller products" do
    own_product
    other_product

    get seller_products_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vaso próprio")
    expect(response.body).not_to include("Vaso alheio")
  end

  # O seletor de categoria do formulário renderiza o breadcrumb de cada opção,
  # e `Category#breadcrumb_name` sobe a árvore uma query por nível. A asserção é
  # sobre o crescimento: o total muda quando a página muda, a inclinação não
  # pode voltar. Diferente do admin, este painel tem tráfego proporcional ao
  # número de artesãos.
  it "does not issue more queries on the product form when categories are added" do
    top = Category.create!(name: "Casa")
    child = Category.create!(name: "Decoração", parent: top)
    Category.create!(name: "Vasos", parent: child)

    get new_seller_product_path
    before = count_queries { get new_seller_product_path }

    other = Category.create!(name: "Moda")
    sub = Category.create!(name: "Acessórios", parent: other)
    Category.create!(name: "Colares", parent: sub)

    get new_seller_product_path
    after = count_queries { get new_seller_product_path }

    expect(after).to eq(before)
  end

  it "searches only within the authenticated seller catalog" do
    own_product
    Product.create!(seller: seller, name: "Caneca própria", sku: "OWN-002", price_cents: 3_000, stock_quantity: 2)
    other_product

    get seller_products_path, params: { q: "Caneca" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Caneca própria")
    expect(response.body).not_to include("Vaso próprio", "Vaso alheio")
  end

  it "does not expose another seller product by changing the id" do
    get seller_product_path(other_product)

    expect(response).to have_http_status(:not_found)
  end

  it "shows the owned product management sections" do
    own_product.product_variants.create!(sku: "OWN-001-AZUL", price_cents: 5_000, stock_quantity: 1, color: "Azul")
    own_product.personalization_options.create!(label: "Nome", required: false, max_length: 20)

    get seller_product_path(own_product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Variantes", "OWN-001-AZUL", "Personalizações", "Galeria")
  end

  it "assigns newly created products to the authenticated seller" do
    expect do
      post seller_products_path, params: { product: { name: "Nova peça", sku: "NEW-001", price_cents: 4_000, currency: "BRL", stock_quantity: 1 } }
    end.to change(seller.products, :count).by(1)

    expect(Product.last.seller).to eq(seller)
  end

  it "appends valid gallery images when updating an owned product" do
    image = fixture_file_upload("sample.png", "image/png")

    expect do
      patch seller_product_path(own_product), params: { product: { images: [ image ] } }
    end.to change { own_product.images.reload.count }.by(1)

    expect(response).to redirect_to(seller_product_path(own_product))
  end

  it "cannot publish while seller approval is pending" do
    seller.update!(status: :pending, approved_at: nil)

    patch publish_seller_product_path(own_product)

    expect(response).to redirect_to(seller_product_path(own_product))
    expect(own_product.reload).to be_draft
  end
end
