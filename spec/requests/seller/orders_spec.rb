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

  it "keeps cancelling out of the list and offers it on the order page" do
    order = create_order_for(own_product)

    get seller_orders_path
    expect(response.body).not_to include(cancel_seller_order_path(order))
    expect(response.body).to include("Aguardando pagamento")

    get seller_order_path(order)
    expect(response.body).to include("Cancelar este pedido", cancel_seller_order_path(order))
  end

  it "does not offer cancelling an order that is already cancelled" do
    order = create_order_for(own_product)
    post cancel_seller_order_path(order)

    get seller_order_path(order)

    expect(response.body).not_to include(cancel_seller_order_path(order))
  end

  it "shows the same amount to receive on the dashboard, the list and the order page after a refund" do
    order = create_order_for(own_product)
    seller_order = order.seller_orders.first
    # 5.000 + 1.000 de frete − 750 de comissão = 5.250; reembolso de 2.000
    # devolve 300 de comissão: 5.250 − 2.000 + 300 = 3.550.
    seller_order.update_columns(status: "partially_refunded", refunded_amount_cents: 2_000, platform_fee_refunded_cents: 300)

    [ seller_root_path, seller_orders_path, seller_order_path(order) ].each do |path|
      get path
      expect(response.body).to include("R$ 35,50"), "#{path} não mostra o valor líquido"
    end

    get seller_order_path(order)
    expect(response.body).to include("Reembolsado ao cliente", "Comissão devolvida", "A receber")
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
    expect(response.body).to include("Da confirmação à entrega")
    expect(response.body).to include("Pedido recebido")
    expect(response.body).to include("Em preparação")
    expect(response.body).to include("Marcar como enviado")
    expect(response.body).to include("Fale com o cliente")
  end

  it "shows the commission rate recorded on the order, not today's rate" do
    order = create_order_for(own_product)
    seller_order = order.seller_order
    seller_order.update!(platform_fee_rate_bps: 800, platform_fee_cents: 400, seller_amount_cents: seller_order.total_cents - 400)

    get seller_order_path(order)

    expect(response.body).to include("Comissão EloShop (8%)")
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

    # Enquanto a EloShop não gera a etiqueta, ela é comprada no painel da
    # SuperFrete; remetente e destinatário explícitos para não confundir o
    # endereço do cliente com o da EloShop.
    it "explains how to send the order through the SuperFrete website" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order)

      get seller_order_path(order)

      steps = Nokogiri::HTML(response.body).at_css("[data-shipping-steps]")
      expect(steps.text).to include("Remetente:", "Destinatário:", "Endereço de entrega")
      expect(steps.at_css("a[href='https://web.superfrete.com'][target='_blank'][rel='noopener noreferrer']")).to be_present
    end

    # O ateliê compra a etiqueta com o valor que o cliente pagou de frete em
    # vista; antes ele só aparecia no resumo financeiro, longe do envio.
    it "shows the shipping the customer paid next to the sending steps" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order, shipping_cents: 2068)

      get seller_order_path(order)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("[data-shipping-paid]").text.squish).to include("Entrega EloShop — Entrega padrão", "R$ 20,68")
      expect(html.at_xpath("//dt[normalize-space()='Frete pago pelo cliente']/following-sibling::dd").text.squish).to eq("R$ 20,68")
    end

    it "tells the seller the label is on them when the order shipped for free" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order, shipping_cents: 0)

      get seller_order_path(order)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("[data-shipping-paid]").text.squish).to include("frete grátis", "a etiqueta é por sua conta")
      expect(html.at_xpath("//dt[normalize-space()='Frete pago pelo cliente']/following-sibling::dd").text.squish).to eq("Grátis")
    end

    it "does not show the sending steps for local pickup" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order, service: Shipping::Quote::LOCAL_PICKUP_SERVICE)

      get seller_order_path(order)

      expect(Nokogiri::HTML(response.body).at_css("[data-shipping-steps]")).to be_nil
      expect(response.body).not_to include("Frete pago pelo cliente")
    end

    # O ateliê compra a etiqueta com o CPF de quem recebe: inteiro só no
    # pedido pago que aguarda envio; antes do pagamento e depois do envio,
    # mascarado.
    it "shows the full recipient CPF only while a paid order awaits dispatch" do
      order = create_order_for(own_product)
      order.update!(recipient_name: "Ana Souza", recipient_cpf: "52998224725", recipient_phone: "27999991234")
      shipment = create_shipment_for(order)

      get seller_order_path(order)
      expect(response.body).to include("Ana Souza", "***.***.***-25", "(27) 99999-1234")
      expect(response.body).not_to include("529.982.247-25")

      order.confirm!
      get seller_order_path(order)
      expect(response.body).to include("529.982.247-25")

      shipment.mark_shipped!
      get seller_order_path(order)
      expect(response.body).not_to include("529.982.247-25")
      expect(response.body).to include("***.***.***-25")
    end

    it "does not show the sending steps once the order was shipped" do
      order = create_order_for(own_product)
      order.confirm!
      create_shipment_for(order).mark_shipped!

      get seller_order_path(order)

      expect(Nokogiri::HTML(response.body).at_css("[data-shipping-steps]")).to be_nil
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

    it "refuses to ship and warns the seller while a full refund is still processing" do
      order = create_order_for(own_product)
      order.confirm!
      shipment = create_shipment_for(order)
      payment = order.payments.create!(gateway: "fake", external_id: "fake-#{SecureRandom.hex(4)}", status: "paid", amount_cents: order.total_cents)
      payment.payment_refunds.create!(idempotency_key: "in-flight-#{SecureRandom.hex(4)}", amount_cents: payment.amount_cents, application_fee_amount_cents: 0)

      get seller_order_path(order)
      expect(response.body).to include("está sendo devolvido ao comprador")
      expect(response.body).not_to include("Marcar como enviado")

      patch ship_seller_order_path(order), params: { carrier: "Correios", service: "PAC", tracking_code: "BR999" }

      expect(response).to redirect_to(seller_order_path(order))
      expect(flash[:alert]).to include("reembolso integral em andamento")
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

  describe "open return requests in the list (ADR 008)" do
    def confirmed_order_for(product)
      create_order_for(product).tap do |order|
        order.update!(status: :confirmed)
        order.seller_order.update!(status: :confirmed)
      end
    end

    it "labels each order with its open request" do
      withdrawn = confirmed_order_for(own_product)
      with_issue = confirmed_order_for(own_product)
      untouched = confirmed_order_for(own_product)
      ReturnRequests::Open.new(seller_order: withdrawn.seller_order, customer: customer, kind: :withdrawal).call
      ReturnRequests::Open.new(seller_order: with_issue.seller_order, customer: customer, kind: :product_issue).call

      get seller_orders_path

      rows = Nokogiri::HTML(response.body).css("tbody tr")
      row_for = ->(order) { rows.find { |row| row.text.include?("##{order.id}") }.text }
      expect(row_for.call(withdrawn)).to include("Desistência solicitada")
      expect(row_for.call(with_issue)).to include("Solicitação aberta")
      expect(row_for.call(untouched)).not_to include("Desistência solicitada", "Solicitação aberta")
    end

    it "does not add a query per order to show the label" do
      2.times do
        order = confirmed_order_for(own_product)
        ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call
      end
      get seller_orders_path

      before = count_queries { ActiveRecord::Base.uncached { get seller_orders_path } }
      4.times do
        order = confirmed_order_for(own_product)
        ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call
      end
      after = count_queries { ActiveRecord::Base.uncached { get seller_orders_path } }

      expect(after).to eq(before)
    end
  end

  describe "with a withdrawal open (ADR 008, decisão A)" do
    it "warns the atelier and refuses marking the order as shipped" do
      order = create_order_for(own_product)
      order.update!(status: :confirmed)
      order.seller_order.update!(status: :confirmed)
      shipment = create_shipment_for(order)
      return_request = ReturnRequests::Open.new(seller_order: order.seller_order, customer: customer, kind: :withdrawal).call.return_request

      get seller_order_path(order)
      expect(response.body).to include(return_request.protocol, "Não envie a peça")

      patch ship_seller_order_path(order), params: { carrier: "Correios", tracking_code: "AA123BR" }
      expect(response).to redirect_to(seller_order_path(order))
      expect(flash[:alert]).to include("desistir da compra", return_request.protocol)
      expect(shipment.reload).to be_pending
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

  def create_shipment_for(order, service: "Entrega padrão", shipping_cents: order.shipping_cents)
    order.seller_order.create_shipment!(
      carrier: "Entrega EloShop",
      service: service,
      shipping_cents: shipping_cents,
      estimated_days: 5
    )
  end
end
