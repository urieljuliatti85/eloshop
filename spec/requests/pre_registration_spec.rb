# frozen_string_literal: true

require "rails_helper"

# Pré-cadastro: com as vendas fechadas, o catálogo e a lista de desejos
# funcionam, mas nada que leve a um pedido passa pelo servidor — esconder o
# botão não basta, porque o POST pode chegar direto pela rota.
RSpec.describe "Pre-registration (sales closed)", type: :request do
  let(:customer) { Customer.create!(name: "Cliente pré-cadastro", email: "pre@example.com", password: "password123") }
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso pré-cadastro", sku: "PRE-001", price_cents: 5_000, stock_quantity: 3, currency: "BRL", status: :active) }
  let(:address) { customer.addresses.create!(street: "Rua", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000") }

  def sign_in_customer
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  def close_sales
    PlatformSetting.instance.update!(sales_opened_at: nil)
  end

  it "shows the product page with 'Vendas em breve' instead of the add-to-cart button" do
    close_sales

    get product_path(product.seller, product.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vendas em breve")
    expect(response.body).not_to include("Adicionar ao carrinho")
  end

  it "refuses adding to the cart even when the request goes straight to the route" do
    close_sales

    expect do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
    end.not_to change(CartItem, :count)

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to include("ainda não abriram")
  end

  it "refuses checkout and order creation" do
    sign_in_customer
    post cart_items_path, params: { product_id: product.id, quantity: 1 }
    close_sales

    get new_order_path
    expect(response).to have_http_status(:redirect)

    expect do
      post orders_path, params: { address_id: address.id }
    end.not_to change(Order, :count)
    expect(flash[:alert]).to include("ainda não abriram")
  end

  it "refuses authorizing a payment" do
    order = Order.create!(customer: customer, status: "pending", subtotal_cents: 1000, shipping_cents: 500, total_cents: 1500,
      shipping_address_snapshot: { street: "Rua" }, idempotency_key: SecureRandom.uuid)
    sign_in_customer
    close_sales

    expect do
      post order_payment_path(order), params: { payment_method: "pix" }
    end.not_to change(Payment, :count)
    expect(flash[:alert]).to include("ainda não abriram")
  end

  it "keeps the wishlist working but refuses moving an item to the cart" do
    sign_in_customer
    close_sales

    post wishlist_items_path, params: { product_id: product.id }
    item = customer.wishlist_items.find_by!(product: product)

    expect do
      post move_to_cart_wishlist_item_path(item)
    end.not_to change(CartItem, :count)
    expect(item.reload).to be_persisted
  end

  it "tells a seller with steps missing that the store is almost ready" do
    close_sales
    sign_in_as(approved_seller.users.first)

    get seller_root_path

    expect(response.body).to include("Sua loja está quase pronta.", "Siga os passos, integre com o Mercado Pago e adicione produtos.", PlatformSetting::SALES_OPENING_PROMISE, "Ver primeiros passos")
    expect(response.body).not_to include("Sua loja está pronta.")
  end

  it "tells a pending seller too, since every atelier waits for the opening" do
    close_sales
    pending_seller = Seller.create!(name: "Ateliê pendente #{SecureRandom.hex(4)}", owner_full_name: "Dona", cpf: generate_valid_cpf)
    user = User.create!(email_address: "pending-pre-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: pending_seller)
    sign_in_as(user)

    get seller_root_path

    expect(response.body).to include("Sua loja está quase pronta.")
  end

  it "tells a seller with every step done that the store is ready" do
    close_sales
    sign_in_as(approved_seller.users.first)
    allow_any_instance_of(Seller).to receive(:setup_steps).and_return(address: true, mercado_pago: true, pix_key: true, product: true, approval: true)

    get seller_root_path

    expect(response.body).to include("Sua loja está pronta.", PlatformSetting::SALES_OPENING_PROMISE, "Ver minha loja")
  end

  it "shows no pre-registration notice once sales are open" do
    sign_in_as(approved_seller.users.first)

    get seller_root_path

    expect(response.body).not_to include(PlatformSetting::SALES_OPENING_PROMISE)
  end

  it "adds to the cart normally once sales are open" do
    expect do
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
    end.to change(CartItem, :count).by(1)
  end
end
