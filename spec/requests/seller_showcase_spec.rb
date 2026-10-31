# frozen_string_literal: true

require "rails_helper"

# Vitrine do pré-cadastro: o admin libera um ateliê pendente para aparecer na
# loja sem o Mercado Pago. Aparecer não é vender — com as vendas abertas, a
# peça dele continua recusada no servidor até a aprovação.
RSpec.describe "Seller showcase", type: :request do
  let(:admin) { User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:seller) { Seller.create!(name: "Ateliê Vitrine #{SecureRandom.hex(4)}", owner_full_name: "Dona da Vitrine", cpf: generate_valid_cpf) }
  let(:seller_user) { User.create!(email_address: "vitrine-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:product) { Product.create!(seller: seller, name: "Vaso da vitrine", sku: "VIT-001", price_cents: 5_000, stock_quantity: 3, currency: "BRL", status: :active) }

  def close_sales
    PlatformSetting.instance.update!(sales_opened_at: nil)
  end

  describe "admin actions" do
    it "lets a platform admin showcase and unshowcase a pending seller" do
      sign_in_as(admin)

      patch showcase_admin_seller_path(seller)
      expect(response).to redirect_to(admin_seller_path(seller))
      expect(seller.reload).to be_showcased
      expect(seller).to be_pending

      patch unshowcase_admin_seller_path(seller)
      expect(seller.reload).not_to be_showcased
    end

    it "refuses to showcase an approved seller" do
      sign_in_as(admin)

      patch showcase_admin_seller_path(approved_seller)

      expect(response).to redirect_to(admin_seller_path(approved_seller))
      expect(flash[:alert]).to include("Só um ateliê pendente")
    end

    it "does not let a seller showcase their own atelier" do
      sign_in_as(seller_user)

      patch showcase_admin_seller_path(seller)

      expect(response).to redirect_to(new_session_path)
      expect(seller.reload).not_to be_showcased
    end

    it "offers the showcase button only for a pending seller" do
      sign_in_as(admin)

      get admin_seller_path(seller)
      expect(response.body).to include("Liberar na vitrine")

      get admin_seller_path(approved_seller)
      expect(response.body).not_to include("Liberar na vitrine")
    end
  end

  describe "storefront" do
    it "keeps a pending seller outside the showcase out of the store" do
      product

      get seller_path(seller.slug)
      expect(response).to have_http_status(:not_found)

      get products_path
      expect(response.body).not_to include("Vaso da vitrine")
    end

    it "lists a showcased seller and its products like an approved one while sales are closed" do
      seller.showcase!
      product
      close_sales

      get seller_path(seller.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vaso da vitrine")
      expect(response.body).to include("Este ateliê está se preparando para começar a vender.")

      get sellers_path
      expect(response.body).to include(seller.name)

      get product_path(seller, product.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vendas em breve")
      expect(response.body).to include("Este ateliê está se preparando para começar a vender.")
      expect(response.body).not_to include("Ateliê em preparação")

      get sitemap_path
      expect(response.body).to include("/artesaos/#{seller.slug}")
    end

    it "says the atelier is not accepting orders once sales are open" do
      seller.showcase!
      product

      get product_path(seller, product.slug)

      expect(response.body).to include("Ateliê em preparação")
      expect(response.body).not_to include("Adicionar ao carrinho")
      expect(response.body).not_to include("Indisponível")
    end

    it "warns the public on the atelier page after sales open, too" do
      seller.showcase!
      product

      get seller_path(seller.slug)

      expect(response.body).to include("Este ateliê está se preparando para começar a vender.")
    end

    it "shows no preparing notice for an approved seller" do
      Product.create!(seller: approved_seller, name: "Vaso aprovado", sku: "APR-001", price_cents: 5_000, stock_quantity: 3, currency: "BRL", status: :active)

      get seller_path(approved_seller.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("se preparando para começar a vender")
    end

    it "refuses adding a showcased seller's product to the cart even through the route" do
      seller.showcase!

      expect do
        post cart_items_path, params: { product_id: product.id, quantity: 1 }
      end.not_to change(CartItem, :count)
    end

    it "refuses adding a showcased seller's variant to the cart through the route" do
      seller.showcase!
      variant = product.product_variants.create!(sku: "VIT-001-AZ", color: "Azul", price_cents: 5_000, stock_quantity: 3)

      expect do
        post cart_items_path, params: { product_id: product.id, product_variant_id: variant.id, quantity: 1 }
      end.not_to change(CartItem, :count)
    end

    it "exposes the showcased seller in the API, with products not available for purchase" do
      seller.showcase!
      product

      get api_v1_seller_path(seller.slug), headers: api_headers
      expect(response).to have_http_status(:ok)

      get api_v1_product_path(seller.slug, product.slug), headers: api_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["available_for_purchase"]).to be(false)
    end

    it "keeps an approved seller in the store after it disconnects Mercado Pago, without selling" do
      seller.connect_mercado_pago!(mercado_pago_credentials)
      seller.approve!(kyc_level_6_confirmed: true)
      product
      seller.disconnect_mercado_pago!

      get seller_path(seller.slug)
      expect(response).to have_http_status(:ok)

      get product_path(seller, product.slug)
      expect(response.body).to include("Ateliê em preparação")
    end
  end

  describe "seller panel" do
    it "warns a showcased seller that the store is visible but not accepting orders" do
      seller.showcase!
      post seller_login_path, params: { email_address: seller_user.email_address, password: "password123" }
      accept_current_seller_terms(seller_user)

      get seller_root_path

      expect(response.body).to include("Sua loja está visível, mas ainda não recebe pedidos.")
    end

    it "explains on the atelier page that selling requires finishing the process" do
      post seller_login_path, params: { email_address: seller_user.email_address, password: "password123" }
      accept_current_seller_terms(seller_user)

      get seller_atelier_path
      expect(response.body).to include("Para vender, você precisa terminar todo o processo.")
      expect(response.body).to include("nós liberaremos a sua vitrine (cadastro de produtos)")

      seller.showcase!
      get seller_atelier_path
      expect(response.body).to include("já liberamos a sua vitrine (cadastro de produtos)")
    end

    it "does not show the process notice on an approved seller's atelier page" do
      user = approved_seller.users.first
      post seller_login_path, params: { email_address: user.email_address, password: "password123" }

      get seller_atelier_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Para vender, você precisa terminar todo o processo.")
    end
  end

  def mercado_pago_credentials
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "showcase-spec-seller",
      access_token: "access-token",
      refresh_token: "refresh-token",
      expires_at: 180.days.from_now,
      live_mode: true,
      test_account: false,
      public_key: "TEST-public-key"
    )
  end
end
