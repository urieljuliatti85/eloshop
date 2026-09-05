# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Storefront sellers", type: :request do
  def create_product(seller:, name:, status: :active)
    Product.create!(seller: seller, name: name, sku: "SEL-#{SecureRandom.hex(4)}",
      price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: status)
  end

  describe "GET /artesaos" do
    it "lists ateliers that have something for sale" do
      create_product(seller: approved_seller, name: "Peça listada")

      get sellers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approved_seller.name)
      expect(response.body).to include(seller_path(approved_seller.slug))
    end

    # Uma vitrine vazia na listagem é um beco — mesmo critério do filtro do
    # catálogo e do sitemap.
    it "omits an approved atelier with nothing published" do
      empty = Seller.create!(name: "Ateliê vazio #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      create_product(seller: approved_seller, name: "Peça de outro")

      get sellers_path

      expect(response.body).not_to include(empty.name)
    end

    it "omits an atelier that is not approved" do
      pending_seller = Seller.create!(name: "Pendente listagem #{SecureRandom.hex(3)}", status: :pending)
      create_product(seller: pending_seller, name: "Peça de pendente")

      get sellers_path

      expect(response.body).not_to include(pending_seller.name)
    end
  end

  describe "the header" do
    it "links to the ateliers listing" do
      get root_path

      expect(response.body).to include("Ateliês")
      expect(response.body).to include(sellers_path)
    end

    # O convite fica na barra de navegação, ao lado de "Painel do Artesão".
    # A home tem outro link com o mesmo rótulo (o banner do carrossel), que
    # aparece para todos — por isso as asserções olham só o <nav>.
    def header_nav
      response.body[/<nav class="hidden[^>]*>(.*?)<\/nav>/m, 1].to_s
    end

    it "invites a visitor to become an artisan" do
      get root_path

      expect(header_nav).to include("Cadastre seu Ateliê")
      expect(header_nav).to include(new_seller_registration_path)
    end

    # O admin administra a plataforma sem ser artesão: pode precisar chegar
    # ao cadastro, então o convite continua no menu para ele.
    it "keeps the invitation for a signed-in admin" do
      admin = User.create!(email_address: "admin-header@eloshop.test", password: "password123")
      sign_in_as(admin)

      get root_path

      expect(header_nav).to include("Cadastre seu Ateliê")
    end

    # Só quem já tem ateliê deixa de ser convidado.
    it "drops the invitation once an artisan is signed in" do
      seller = Seller.create!(name: "Ateliê logado #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      user = User.create!(email_address: "artesao-header@eloshop.test", password: "password123", role: :seller, seller: seller)
      sign_in_as(user)

      get root_path

      expect(header_nav).not_to include("Cadastre seu Ateliê")
    end
  end

  describe "GET /artesaos/:slug" do
    it "shows the atelier and its published products" do
      product = create_product(seller: approved_seller, name: "Vaso do ateliê público")

      get seller_path(approved_seller.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approved_seller.name)
      expect(response.body).to include(product.name)
    end

    it "omits products that are not publicly visible" do
      draft = create_product(seller: approved_seller, name: "Rascunho oculto", status: :draft)

      get seller_path(approved_seller.slug)

      expect(response.body).not_to include(draft.name)
    end

    it "omits products from another atelier" do
      other = Seller.create!(name: "Ateliê vizinho #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      alheio = create_product(seller: other, name: "Peça de outro ateliê")

      get seller_path(approved_seller.slug)

      expect(response.body).not_to include(alheio.name)
    end

    # A vitrine só existe para artesão aprovado — a mesma condição que
    # `publicly_visible` exige dos produtos.
    it "returns 404 for an atelier that is not approved" do
      pending_seller = Seller.create!(name: "Ateliê pendente #{SecureRandom.hex(3)}", status: :pending)

      get seller_path(pending_seller.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "renders an approved atelier with no published products" do
      get seller_path(approved_seller.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ainda não tem peças publicadas")
    end

    # Sem breadcrumb a página vira um beco: chega-se nela a partir de um
    # produto e não há como voltar à loja pela própria página.
    it "renders a breadcrumb back to the storefront" do
      get seller_path(approved_seller.slug)

      expect(response.body).to include("Início")
      expect(response.body).to include("Loja")
      expect(response.body).to include(products_path)
    end

    it "sets a canonical URL of its own" do
      get seller_path(approved_seller.slug)

      expect(response.body).to include(seller_url(approved_seller.slug))
    end
  end

  describe "the product page" do
    it "links the atelier name to its public page" do
      product = create_product(seller: approved_seller, name: "Vaso com link")

      get product_path(product.seller, product.slug)

      expect(response.body).to include(seller_path(approved_seller.slug))
    end
  end
end
