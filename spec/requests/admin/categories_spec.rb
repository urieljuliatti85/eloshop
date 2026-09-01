# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin categories", type: :request do
  let(:user) { User.create!(email_address: "category-admin@example.com", password: "password", password_confirmation: "password") }
  let!(:category) { Category.create!(name: "Casa") }

  describe "GET /admin/categories" do
    it "redirects unauthenticated users to login" do
      get admin_categories_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated users to list categories" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_categories_path

      expect(response).to have_http_status(:ok)
    end
  end

  # A listagem e o seletor de categoria pai renderizam o breadcrumb de cada
  # categoria, e `Category#breadcrumb_name` sobe a árvore uma query por nível.
  # A asserção é sobre o crescimento, não sobre um total absoluto.
  describe "custo por categoria" do
    def build_branch(name)
      top = Category.create!(name: name)
      child = Category.create!(name: "#{name} filha", parent: top)
      Category.create!(name: "#{name} neta", parent: child)
    end

    before { post session_path, params: { email_address: user.email_address, password: "password" } }

    it "does not issue more queries on the index when categories are added" do
      build_branch("Ramo A")
      get admin_categories_path
      before = count_queries { get admin_categories_path }

      build_branch("Ramo B")
      get admin_categories_path
      after = count_queries { get admin_categories_path }

      expect(after).to eq(before)
    end

    it "does not issue more queries on the form when categories are added" do
      build_branch("Ramo A")
      get new_admin_category_path
      before = count_queries { get new_admin_category_path }

      build_branch("Ramo B")
      get new_admin_category_path
      after = count_queries { get new_admin_category_path }

      expect(after).to eq(before)
    end
  end

  describe "POST /admin/categories" do
    it "creates a top-level category" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_categories_path, params: { category: { name: "Moda" } }
      end.to change(Category, :count).by(1)

      expect(response).to redirect_to(admin_categories_path)
    end

    it "creates a subcategory" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      post admin_categories_path, params: { category: { name: "Decoração", parent_id: category.id } }

      expect(Category.find_by!(name: "Decoração").parent).to eq(category)
    end

    it "rejects invalid category names" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_categories_path, params: { category: { name: "" } }
      end.not_to change(Category, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/categories/:id" do
    it "updates a category" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch admin_category_path(category), params: { category: { name: "Casa e Decoração" } }

      expect(response).to redirect_to(admin_categories_path)
      expect(category.reload.name).to eq("Casa e Decoração")
    end
  end

  describe "DELETE /admin/categories/:id" do
    it "destroys a category without products or children" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        delete admin_category_path(category)
      end.to change(Category, :count).by(-1)
    end

    it "does not destroy a category that still has products" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      product = Product.create!(seller: approved_seller, name: "Vaso categoria", sku: "CAT-DEL-001", price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active, category: category)

      expect do
        delete admin_category_path(category)
      end.not_to change(Category, :count)

      expect(response).to redirect_to(admin_categories_path)
      expect(product.reload.category).to eq(category)
    end
  end
end
