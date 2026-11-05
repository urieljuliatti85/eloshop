require "test_helper"

module ShippingLabels
  class RequestTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper
    include ActiveJob::TestHelper

    setup do
      prepare_label_scenario
      @client = FakeClient.new
    end

    test "re-quotes on the server and records the label with SuperFrete's price and package" do
      @client.quote_result = [ @client.option(service_code: 2, service_name: "SEDEX", price_cents: 3457, width_cm: 16, length_cm: 24) ]

      label = nil
      assert_enqueued_with(job: PurchaseShippingLabelJob) { label = request(service_code: "2") }

      assert label.draft?
      assert_equal [ 2, "SEDEX", 3457 ], [ label.service_code, label.service_name, label.quoted_price_cents ]
      assert_equal [ 16, 24 ], [ label.width_cm, label.length_cm ]
      assert_equal "sf-account-1", label.superfrete_account_id
    end

    test "refuses a service that was not quoted" do
      error = assert_raises(Refused) { request(service_code: "17") }
      assert_match "não está disponível", error.message
    end

    test "refuses when the SuperFrete account is not the atelier's own e-mail" do
      @seller.update!(superfrete_account_email: "outra-pessoa@example.com")

      error = assert_raises(Refused) { request }
      assert_match "mesmo e-mail", error.message
      assert_not @client.called?(:quote)
    end

    test "refuses an order without the recipient CPF" do
      @order.update!(recipient_cpf: nil)

      assert_raises(Refused) { request }
    end

    test "refuses an unpaid order and an open withdrawal" do
      @seller_order.update!(status: :pending)
      assert_raises(Refused) { request }

      @seller_order.update!(status: :confirmed)
      ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :withdrawal).call
      error = assert_raises(Refused) { request }
      assert_match "desistir da compra", error.message
    end

    test "refuses a second label while one is active, but allows a new one after a failure" do
      build_label(status: :failed, provider_order_id: nil)
      request

      error = assert_raises(Refused) { request }
      assert_equal "Já existe uma etiqueta para este pedido.", error.message
    end

    test "refuses when labels are switched off" do
      Rails.configuration.x.shipping.labels_enabled = false
      assert_raises(Refused) { request }
    ensure
      Rails.configuration.x.shipping.labels_enabled = true
    end

    test "refuses a package without measures" do
      error = assert_raises(Refused) { request(weight_grams: "0") }
      assert_match "Informe altura", error.message
    end

    private

    def request(service_code: "1", weight_grams: "500")
      Request.new(shipment: @shipment, service_code: service_code, height_cm: "10", width_cm: "15", length_cm: "20",
        weight_grams: weight_grams, client: @client).call
    end
  end
end
