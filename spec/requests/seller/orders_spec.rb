require "rails_helper"

RSpec.describe "Seller orders", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Pedidos", owner_full_name: "Proprietário Teste", cpf: "12444457463", status: :approved, approved_at: Time.current) }
  let(:other_seller) { Seller.create!(name: "Outro Ateliê Pedidos", owner_full_name: "Proprietário Teste", cpf: "12555569197", status: :approved, approved_at: Time.current) }
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

  it "shows the delivery timeline for the seller order" do
    order = create_order_for(own_product)
    order.confirm!
    create_shipment_for(order)

    get seller_order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Linha do tempo")
    expect(response.body).to include("Pedido recebido")
    expect(response.body).to include("Em preparação")
    expect(response.body).to include("Marcar como enviado")
    expect(response.body).to include("Fale com o cliente")
  end

  it "uses pickup wording for an order collected at the atelier" do
    order = create_order_for(own_product)
    order.confirm!
    create_shipment_for(order, service: Shipping::Quote::LOCAL_PICKUP_SERVICE)

    get seller_order_path(order)

    expect(response.body).to include("Pronto para retirada")
    expect(response.body).to include("Retirado")
    expect(response.body).to include("Marcar como pronto para retirada")
  end

  describe "PATCH /painel/orders/:id/start_production" do
    let(:made_to_order_product) { Product.create!(seller: seller, name: "Peça sob encomenda", sku: "ORDER-MTO-001", price_cents: 5_000, stock_quantity: 2) }

    def confirmed_custom_order
      create_order_for(made_to_order_product).tap do |order|
        order.order_items.first.update!(production_time_snapshot: "7 a 10 dias úteis")
        order.confirm!
        order.seller_order.update!(status: :confirmed)
        create_shipment_for(order)
      end
    end

    it "records the start of production, tells the buyer and shows it on both order pages" do
      order = confirmed_custom_order

      get seller_order_path(order)
      expect(response.body).to include("Iniciei a produção")

      patch start_production_seller_order_path(order)

      expect(response).to redirect_to(seller_order_path(order))
      seller_order = order.seller_order.reload
      expect(seller_order.production_started_at).to be_present
      expect(order.order_events.production_started.count).to eq(1)
      notification = customer.notifications.production_started.last
      expect(notification.body).to include("##{order.id}")

      get seller_order_path(order)
      expect(response.body).to include("Produção iniciada em")
      expect(response.body).not_to include("Iniciei a produção")

      post customer_session_path, params: { email: customer.email, password: "password123" }
      get order_path(order)
      expect(response.body).to include("Produção iniciada em")
    end

    it "cannot be undone or repeated, and keeps the original timestamp" do
      order = confirmed_custom_order
      patch start_production_seller_order_path(order)
      original = order.seller_order.reload.production_started_at

      expect {
        patch start_production_seller_order_path(order)
      }.not_to change { customer.notifications.production_started.count }

      expect(flash[:alert]).to include("não permite")
      expect(order.seller_order.reload.production_started_at).to eq(original)
    end

    it "does not apply to a ready-made piece" do
      order = create_order_for(own_product)
      order.confirm!
      order.seller_order.update!(status: :confirmed)
      create_shipment_for(order)

      get seller_order_path(order)
      expect(response.body).not_to include("Iniciei a produção")

      patch start_production_seller_order_path(order)

      expect(flash[:alert]).to be_present
      expect(order.seller_order.reload.production_started_at).to be_nil
      expect(customer.notifications.production_started).to be_empty
    end

    it "does not apply before the payment is confirmed" do
      order = create_order_for(made_to_order_product)
      order.order_items.first.update!(production_time_snapshot: "7 a 10 dias úteis")

      patch start_production_seller_order_path(order)

      expect(flash[:alert]).to be_present
      expect(order.seller_order.reload.production_started_at).to be_nil
    end

    it "does not let a seller start production on another seller's order" do
      other_product.update!(availability_type: :made_to_order, production_time_min_days: 3, production_time_max_days: 5)
      other_order = create_order_for(other_product)
      other_order.order_items.first.update!(production_time_snapshot: "3 a 5 dias úteis")
      other_order.confirm!
      other_order.seller_order.update!(status: :confirmed)
      create_shipment_for(other_order)

      patch start_production_seller_order_path(other_order)

      expect(response).to have_http_status(:not_found)
      expect(other_order.seller_order.reload.production_started_at).to be_nil
    end

    it "is filled in by shipping when the seller never marked it, without overwriting a prior mark" do
      unmarked = confirmed_custom_order
      patch ship_seller_order_path(unmarked), params: { carrier: "Correios", service: "PAC", tracking_code: "BR123" }
      expect(unmarked.seller_order.reload.production_started_at).to be_present

      marked = confirmed_custom_order
      patch start_production_seller_order_path(marked)
      original = marked.seller_order.reload.production_started_at
      patch ship_seller_order_path(marked), params: { carrier: "Correios", service: "PAC", tracking_code: "BR456" }
      expect(marked.seller_order.reload.production_started_at).to eq(original)
    end
  end

  describe "PATCH /painel/orders/:id/ship" do
    it "shows shipment details before marking the seller's confirmed order as shipped" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order)

      get seller_order_path(order)

      expect(response.body).to include("Detalhes do Envio")
      expect(response.body).to include("Código de rastreamento (opcional)")
    end

    it "marks the seller's confirmed order as shipped with the submitted details" do
      order = create_order_for(own_product)
      order.confirm!
      shipment = create_shipment_for(order)

      expect do
        patch ship_seller_order_path(order), params: {
          carrier: "Correios",
          service: "SEDEX",
          tracking_code: "AA123456789BR"
        }
      end.to have_enqueued_job(NotifyCustomerOfShipmentJob)

      expect(response).to redirect_to(seller_order_path(order))
      expect(shipment.reload).to be_shipped
      expect(shipment.shipped_at).to be_present
      expect(shipment.carrier).to eq("Correios")
      expect(shipment.service).to eq("SEDEX")
      expect(shipment.tracking_code).to eq("AA123456789BR")

      notification = customer.notifications.order_shipped.last
      expect(notification).to be_present
      expect(notification.url).to eq(order_path(order))
    end

    it "does not advance an unpaid order" do
      order = create_order_for(own_product)
      shipment = create_shipment_for(order)

      patch ship_seller_order_path(order)

      expect(response).to redirect_to(seller_order_path(order))
      expect(shipment.reload).to be_pending
    end

    it "does not allow updating another seller's shipment" do
      other_order = create_order_for(other_product)
      other_order.confirm!
      shipment = create_shipment_for(other_order)

      patch ship_seller_order_path(other_order)

      expect(response).to have_http_status(:not_found)
      expect(shipment.reload).to be_pending
    end
  end

  describe "PATCH /painel/orders/:id/deliver" do
    it "marks a shipped order as delivered and notifies the customer" do
      order = create_order_for(own_product)
      order.confirm!
      shipment = create_shipment_for(order)
      shipment.mark_shipped!

      expect { patch deliver_seller_order_path(order) }.to have_enqueued_job(NotifyCustomerOfDeliveryJob).with(order.seller_order)

      expect(response).to redirect_to(seller_order_path(order))
      expect(shipment.reload).to be_delivered
      expect(shipment.delivered_at).to be_present

      notification = customer.notifications.order_delivered.last
      expect(notification).to be_present
      expect(notification.url).to eq(order_path(order))
    end
  end

  describe "POST /painel/orders/:id/cancel" do
    it "cancels the seller's own pending order and restores stock" do
      order = create_order_for(own_product)

      post cancel_seller_order_path(order)

      expect(response).to redirect_to(seller_order_path(order))
      expect(order.reload.cancelled?).to be(true)
      # create_order_for monta o pedido direto, sem passar por
      # Checkout::CreateOrder, então nunca debitou estoque de fato — o
      # cancelamento ainda incrementa +1, o que é o comportamento correto.
      expect(own_product.reload.stock_quantity).to eq(3)
    end

    it "refuses to cancel an order with an authorized payment" do
      order = create_order_for(own_product)
      order.payments.create!(gateway: "fake", external_id: "fake-seller-cancel", status: :paid, amount_cents: order.total_cents, application_fee_cents: 0)

      post cancel_seller_order_path(order)

      expect(response).to redirect_to(seller_order_path(order))
      expect(order.reload.pending?).to be(true)
    end

    it "does not allow cancelling another seller's order" do
      other_order = create_order_for(other_product)

      post cancel_seller_order_path(other_order)

      expect(response).to have_http_status(:not_found)
      expect(other_order.reload.pending?).to be(true)
    end
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
      platform_fee = SellerOrder.platform_fee_cents_for(subtotal_cents: order.subtotal_cents, discount_cents: 0)
      seller_order = order.seller_orders.create!(
        seller: product.seller,
        subtotal_cents: order.subtotal_cents,
        discount_cents: 0,
        shipping_cents: order.shipping_cents,
        total_cents: order.total_cents,
        platform_fee_cents: platform_fee,
        seller_amount_cents: order.total_cents - platform_fee
      )
      order.order_items.create!(
        seller_order: seller_order,
        product: product,
        product_name: product.name,
        sku: product.sku,
        unit_price_cents: product.price_cents,
        quantity: 1
      )
    end
  end

  def create_shipment_for(order, service: "Entrega padrão")
    order.seller_order.create_shipment!(
      carrier: "Entrega EloShop",
      service: service,
      shipping_cents: order.shipping_cents,
      estimated_days: 5
    )
  end
end
