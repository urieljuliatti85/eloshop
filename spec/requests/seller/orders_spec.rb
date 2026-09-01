require "rails_helper"

RSpec.describe "Seller orders", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Pedidos", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Pedidos", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "orders-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:customer) { Customer.create!(name: "Cliente", email: "customer-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:own_product) { Product.create!(seller: seller, name: "Peça própria", sku: "ORDER-OWN-001", price_cents: 5_000, stock_quantity: 2) }
  let(:other_product) { Product.create!(seller: other_seller, name: "Peça alheia", sku: "ORDER-OTHER-001", price_cents: 5_000, stock_quantity: 2) }

  before { sign_in_as(user) }

  it "lists only orders containing the authenticated seller products" do
    own_order = create_order_for(own_product)
    other_order = create_order_for(other_product)

    get seller_orders_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("##{own_order.id}")
    expect(response.body).not_to include("##{other_order.id}")
  end

  it "does not expose another seller order by changing the id" do
    other_order = create_order_for(other_product)

    get seller_order_path(other_order)

    expect(response).to have_http_status(:not_found)
  end

  private

  def create_order_for(product)
    Order.create!(
      customer: customer,
      subtotal_cents: product.price_cents,
      shipping_cents: 1_000,
      discount_cents: 0,
      total_cents: product.price_cents + 1_000,
      shipping_address_snapshot: { "street" => "Rua Um", "number" => "1" },
      idempotency_key: SecureRandom.hex(12)
    ).tap do |order|
      order.order_items.create!(
        product: product,
        product_name: product.name,
        sku: product.sku,
        unit_price_cents: product.price_cents,
        quantity: 1
      )
    end
  end
end
