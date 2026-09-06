# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin products", type: :request do
  before do
    clear_product_data!
  end

  let(:user) do
    User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123")
  end

  describe "GET /admin/products" do
    it "redirects unauthenticated users to login" do
      get admin_products_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated users to list products" do
      sign_in_as(user)

      get admin_products_path

      expect(response).to have_http_status(:ok)
    end
  end

  # O seletor de categoria renderiza o breadcrumb de cada opção; sem a árvore
  # carregada, cada uma sobe a hierarquia com uma query por nível. Asserção
  # sobre crescimento, não sobre total.
  describe "GET /admin/products/:id/edit" do
    it "renders the form with the category selector" do
      sign_in_as(user)
      top = Category.create!(name: "Casa")
      child = Category.create!(name: "Decoração", parent: top)
      product = Product.create!(seller: approved_seller, name: "Vaso", sku: "EDIT-1", price_cents: 1_000, stock_quantity: 1, category: child)

      get edit_admin_product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Casa &gt; Decoração")
    end
  end

  describe "custo por categoria" do
    def build_branch(name)
      top = Category.create!(name: name)
      child = Category.create!(name: "#{name} filha", parent: top)
      Category.create!(name: "#{name} neta", parent: child)
    end

    it "does not issue more queries on the form when categories are added" do
      sign_in_as(user)
      build_branch("Ramo A")

      get new_admin_product_path
      before = count_queries { get new_admin_product_path }

      build_branch("Ramo B")
      get new_admin_product_path
      after = count_queries { get new_admin_product_path }

      expect(after).to eq(before)
    end
  end

  describe "POST /admin/products" do
    it "creates a product with valid attributes" do
      sign_in_as(user)

      expect do
        post admin_products_path, params: {
          product: {
            seller_id: approved_seller.id,
            name: "Cesto de vime",
            description: "Cesto trançado à mão",
            price: "59,90",
            currency: "BRL",
            sku: "CESTO-001",
            stock_quantity: 2
          }
        }
      end.to change(Product, :count).by(1)

      expect(response).to redirect_to(admin_product_path(Product.last))
    end

    it "does not create an invalid product" do
      sign_in_as(user)

      expect do
        post admin_products_path, params: { product: { name: "", sku: "", price: "", stock_quantity: 0 } }
      end.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/products/:id" do
    it "updates the product name" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso original", sku: "PATCH-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      patch admin_product_path(product), params: { product: { name: "Vaso artesanal azul (edição limitada)" } }

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload.name).to eq("Vaso artesanal azul (edição limitada)")
    end
  end

  describe "GET /admin/products/:id" do
    it "shows the product" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso detalhe", sku: "SHOW-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      get admin_product_path(product)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/products/:id/publish" do
    # Sem peso o frete real cotaria errado, e é o artesão quem absorve a
    # diferença — o produto não pode ir ao ar assim.
    it "refuses to publish a product without weight and dimensions" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Sem medidas", sku: "PUB-DIM", price_cents: 8_990,
        stock_quantity: 3, currency: "BRL", status: "draft")

      patch publish_admin_product_path(product)

      expect(product.reload).to be_draft
    end

    it "publishes a draft product" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso publicar", sku: "PUB-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "draft",
        weight_grams: 500, length_cm: 20, width_cm: 15, height_cm: 10)

      patch publish_admin_product_path(product)

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload).to be_active
    end

    it "rejects an invalid status transition" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso descontinuado", sku: "PUB-002", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "discontinued")

      patch publish_admin_product_path(product)

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload).to be_discontinued
    end
  end

  describe "PATCH /admin/products/:id/unpublish" do
    it "unpublishes an active product" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso ativo", sku: "UNPUB-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")

      patch unpublish_admin_product_path(product)

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload).to be_draft
    end
  end

  describe "PATCH /admin/products/:id/discontinue" do
    it "discontinues a product" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso descontinuar", sku: "DISC-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")

      patch discontinue_admin_product_path(product)

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload).to be_discontinued
    end
  end
end
