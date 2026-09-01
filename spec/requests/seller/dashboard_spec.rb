require "rails_helper"

RSpec.describe "Seller dashboard", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Horizonte", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "horizonte@example.com", password: "password123", role: :seller, seller: seller) }
  let(:customer) { Customer.create!(name: "Cliente do Ateliê", email: "cliente-horizonte@example.com", password: "password123") }
  let(:oauth) { instance_double(Marketplace::MercadoPagoOauth, configured?: false, sandbox?: false) }

  before { allow(Marketplace::MercadoPagoOauth).to receive(:new).and_return(oauth) }

  it "redirects unauthenticated visitors to login" do
    get seller_root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the seller operation without exposing another seller data" do
    sign_in_as(user)
    own_product = Product.create!(seller: seller, name: "Cesto Horizonte", sku: "HORIZONTE-1", price_cents: 8_000, stock_quantity: 2, status: :active)
    other_seller = Seller.create!(name: "Outro Ateliê #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
    Product.create!(seller: other_seller, name: "Produto Alheio", sku: "ALHEIO-1", price_cents: 3_000, stock_quantity: 2, status: :active)
    seller_order = create_seller_order(own_product)

    get seller_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Crie, publique e acompanhe cada venda")
    expect(response.body).to include("Buscar no seu catálogo")
    expect(response.body).to include("Cesto Horizonte")
    expect(response.body).to include("Pedido ##{seller_order.order_id}")
    expect(response.body).to include("Cliente do Ateliê")
    expect(response.body).not_to include("Produto Alheio")
  end

  private

  def create_seller_order(product)
    order = Order.create!(
      customer: customer,
      subtotal_cents: product.price_cents,
      shipping_cents: 1_000,
      discount_cents: 0,
      total_cents: product.price_cents + 1_000,
      shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" },
      idempotency_key: SecureRandom.hex(12)
    )
    platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: order.subtotal_cents, discount_cents: 0)
    order.seller_orders.create!(
      seller: seller,
      subtotal_cents: order.subtotal_cents,
      discount_cents: 0,
      shipping_cents: order.shipping_cents,
      total_cents: order.total_cents,
      platform_fee_cents: platform_fee,
      seller_amount_cents: order.total_cents - platform_fee
    )
  end
end
