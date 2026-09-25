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

    it "paginates products" do
      sign_in_as(user)
      per_page = Paginatable::DEFAULT_PER_PAGE
      (per_page * 2 - Product.count).times { |i| Product.create!(seller: approved_seller, name: "Produto #{i}", sku: "PAG-#{i}-#{SecureRandom.hex(2)}", price_cents: 1_000, stock_quantity: 1, status: "active") }

      get admin_products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 1 de 2")

      get admin_products_path(page: 2)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 2 de 2")
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

    # Mesmo box já existente no painel do vendedor (app/views/seller_portal/products/_form.html.erb) —
    # o admin não tinha esses campos liberados em product_params.
    it "updates the product's fixed shipping and local pickup" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso frete", sku: "PATCH-002", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      patch admin_product_path(product), params: { product: {
        fixed_shipping: "20,00", fixed_shipping_estimated_days: 8, local_pickup_enabled: "1"
      } }

      expect(response).to redirect_to(admin_product_path(product))
      product.reload
      expect(product.fixed_shipping_cents).to eq(2000)
      expect(product.fixed_shipping_estimated_days).to eq(8)
      expect(product.local_pickup_enabled).to be(true)
    end

    it "updates the product's free shipping toggle" do
      sign_in_as(user)
      product = Product.create!(seller: approved_seller, name: "Vaso frete grátis", sku: "PATCH-003", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      patch admin_product_path(product), params: { product: { free_shipping: "1" } }

      expect(response).to redirect_to(admin_product_path(product))
      expect(product.reload.free_shipping).to be(true)
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

  describe "PATCH /admin/products/bulk_discontinue" do
    it "discontinues every selected product across sellers" do
      sign_in_as(user)
      product_a = Product.create!(seller: approved_seller, name: "Vaso A", sku: "BULK-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")
      product_b = Product.create!(seller: approved_seller, name: "Vaso B", sku: "BULK-002", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")

      patch bulk_discontinue_admin_products_path, params: { product_ids: [ product_a.id, product_b.id ] }

      expect(response).to redirect_to(admin_products_path)
      expect(product_a.reload).to be_discontinued
      expect(product_b.reload).to be_discontinued
    end

    it "skips products with an invalid transition and reports how many were skipped" do
      sign_in_as(user)
      active_product = Product.create!(seller: approved_seller, name: "Vaso ativo", sku: "BULK-003", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")
      draft_product = Product.create!(seller: approved_seller, name: "Vaso rascunho", sku: "BULK-004", price_cents: 8_990, stock_quantity: 3, currency: "BRL")

      patch bulk_discontinue_admin_products_path, params: { product_ids: [ active_product.id, draft_product.id ] }

      expect(active_product.reload).to be_discontinued
      expect(draft_product.reload).to be_draft

      follow_redirect!
      expect(response.body).to include("1 produto(s) descontinuado(s). 1 não puderam ser alterados")
    end
  end

  describe "PATCH /admin/products/bulk_unpublish" do
    it "unpublishes every selected product across sellers" do
      sign_in_as(user)
      product_a = Product.create!(seller: approved_seller, name: "Vaso A", sku: "BULKU-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")
      product_b = Product.create!(seller: approved_seller, name: "Vaso B", sku: "BULKU-002", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")

      patch bulk_unpublish_admin_products_path, params: { product_ids: [ product_a.id, product_b.id ] }

      expect(response).to redirect_to(admin_products_path)
      expect(product_a.reload).to be_draft
      expect(product_b.reload).to be_draft
    end

    it "skips products with an invalid transition and reports how many were skipped" do
      sign_in_as(user)
      active_product = Product.create!(seller: approved_seller, name: "Vaso ativo", sku: "BULKU-003", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "active")
      discontinued_product = Product.create!(seller: approved_seller, name: "Vaso fora de linha", sku: "BULKU-004", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: "discontinued")

      patch bulk_unpublish_admin_products_path, params: { product_ids: [ active_product.id, discontinued_product.id ] }

      expect(active_product.reload).to be_draft
      expect(discontinued_product.reload).to be_discontinued

      follow_redirect!
      expect(response.body).to include("1 produto(s) escondido(s). 1 não puderam ser alterados")
    end
  end
end
