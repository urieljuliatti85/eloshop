require "test_helper"

module ShippingLabels
  class PurchaseTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper

    setup do
      prepare_label_scenario
      @client = FakeClient.new
    end

    test "creates the order at SuperFrete, records its id and pays it once" do
      label = build_label

      purchase(label)

      assert label.reload.purchased?
      assert_equal "sf-order-1", label.provider_order_id
      assert_equal "AA123456789BR", label.tracking_code
      assert_equal 2351, label.price_cents
      assert label.purchased_at.present?
      assert_equal 1, @client.count(:checkout)
    end

    test "sends the recipient the buyer informed, with the CPF, and the EloShop reference in options.tags" do
      purchase(build_label)

      payload = @client.calls.find { |call| call.first == :create_cart }.last
      assert_equal "52998224725", payload.dig(:to, :document)
      assert_equal "Ana Souza", payload.dig(:to, :name)
      assert_equal "01000000", payload.dig(:to, :postal_code)
      assert_equal "01001000", payload.dig(:from, :postal_code)
      assert_equal 1, payload[:service]
      assert_equal "eloshop-shipment-#{@shipment.id}", payload.dig(:options, :tags, 0, :tag)
    end

    test "without wallet balance the label fails with SuperFrete's message and the unpaid order is cancelled" do
      @client.checkout_result = Client::Rejected.new("Sem saldo na carteira!")
      @client.info_result = @client.info(status: "pending")
      label = build_label

      purchase(label)

      assert label.reload.failed?
      assert_equal "Sem saldo na carteira!", label.failure_message
      assert @client.called?(:cancel)
    end

    test "a refusal of an order that was in fact paid becomes purchased, not failed" do
      @client.checkout_result = Client::Rejected.new("pedido já pago")
      label = build_label

      purchase(label)

      assert label.reload.purchased?
      assert_not @client.called?(:cancel)
    end

    test "an uncertain checkout is settled by looking the order up, without paying again" do
      @client.checkout_result = Client::Ambiguous.new("SuperFrete respondeu 500")
      label = build_label

      purchase(label)

      assert label.reload.purchased?
      assert_equal 1, @client.count(:checkout)
      assert @client.called?(:order_info)
    end

    test "an uncertain checkout still pending at SuperFrete stays purchasing and asks to check again" do
      @client.checkout_result = Client::Ambiguous.new("sem resposta da SuperFrete")
      @client.info_result = @client.info(status: "pending")
      label = build_label

      assert_raises(Purchase::Retry) { purchase(label) }
      assert label.reload.purchasing?

      # A nova tentativa só confere; nunca reenvia o pagamento.
      assert_raises(Purchase::Retry) { purchase(label) }
      assert_equal 1, @client.count(:checkout)
    end

    test "a withdrawal opened while the job waited stops the purchase and cancels the unpaid order" do
      label = build_label(status: :cart_created)
      ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :withdrawal).call

      purchase(label)

      assert label.reload.cancelled?
      assert_match "desistir da compra", label.failure_message
      assert_not @client.called?(:checkout)
      assert @client.called?(:cancel)
    end

    test "a full refund in progress stops the purchase" do
      label = build_label(status: :cart_created)
      payment = @order.payments.create!(gateway: "fake", external_id: "fake-label", status: "paid", amount_cents: @order.total_cents)
      payment.payment_refunds.create!(idempotency_key: "refund-label", amount_cents: payment.amount_cents, application_fee_amount_cents: 0)

      purchase(label)

      assert label.reload.cancelled?
      assert_not @client.called?(:checkout)
    end

    test "does not pay with another account connected after the label was requested" do
      label = build_label
      @seller.connect_superfrete!(access_token: "outro-token", sandbox: @seller.superfrete_sandbox?,
        account: Marketplace::SuperfreteOauth::Account.new(id: "outra-conta", email: users(:seller).email_address))

      purchase(label)

      assert label.reload.failed?
      assert_not @client.called?(:create_cart)
    end

    test "a refusal when creating the order fails the label without paying" do
      @client.cart_result = Client::Rejected.new("Campo CPF/CNPJ do destinatário é obrigatório")
      label = build_label

      purchase(label)

      assert label.reload.failed?
      assert_not @client.called?(:checkout)
    end

    test "an uncertain order creation is retried from draft" do
      @client.cart_result = Client::Ambiguous.new("sem resposta da SuperFrete")
      label = build_label

      assert_raises(Purchase::Retry) { purchase(label) }
      assert label.reload.draft?
    end

    # QA de 2026-11-05 (N1): o pedido criado lá saiu mais caro que o cotado e
    # a compra pagava sem o ateliê ver.
    test "does not pay when SuperFrete's order costs more than the quote the atelier approved" do
      @client.cart_result = { id: "sf-order-1", price_cents: 9_999 }
      label = build_label(quoted_price_cents: 2_351)

      purchase(label)

      assert label.reload.cancelled?
      assert_equal "O preço da etiqueta mudou de R$ 23,51 para R$ 99,99. Nada foi cobrado: cote de novo.", label.failure_message
      assert_not @client.called?(:checkout)
      assert @client.called?(:cancel)
    end

    test "pays when SuperFrete's order costs the same or less than the quote" do
      @client.cart_result = { id: "sf-order-1", price_cents: 2_300 }

      label = build_label(quoted_price_cents: 2_351)
      purchase(label)

      assert label.reload.purchased?
    end

    # QA de 2026-11-05 (C3): dois jobs com a etiqueta em rascunho criavam dois
    # pedidos lá; o do perdedor ficava pendente e órfão.
    test "the job that loses the race to record the order cancels the one it created" do
      label = build_label
      @client.cart_result = lambda do
        ShippingLabel.where(id: label.id).update_all(status: "cart_created", provider_order_id: "sf-order-winner", price_cents: 2351)
        { id: "sf-order-loser", price_cents: 2351 }
      end

      purchase(label)

      assert_equal "sf-order-winner", label.reload.provider_order_id
      assert_includes @client.calls, [ :cancel, "sf-order-loser" ]
    end

    test "a purchased label is left alone" do
      label = build_label(status: :purchased)

      purchase(label)

      assert_empty @client.calls
    end

    private

    def purchase(label)
      Purchase.new(label, client: @client, order_url: "https://eloshop.test/painel/orders/#{@order.id}").call
    end
  end
end
