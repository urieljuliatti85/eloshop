require "test_helper"

module ShippingLabels
  class CancelTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper

    setup do
      prepare_label_scenario
      @client = FakeClient.new
    end

    test "cancels a purchased label at SuperFrete and frees the shipment for a new one" do
      label = build_label(status: :purchased)

      Cancel.new(label, client: @client).call

      assert label.reload.cancelled?
      assert label.cancelled_at.present?
      assert @client.called?(:cancel)
      assert_not @shipment.shipping_labels.active.exists?
    end

    test "treats a repeated cancel as done when SuperFrete shows it cancelled" do
      @client.cancel_result = Client::Rejected.new("Esse pedido não pode mais ser cancelado!")
      @client.info_result = @client.info(status: "canceled")
      label = build_label(status: :purchased)

      Cancel.new(label, client: @client).call

      assert label.reload.cancelled?
    end

    test "refuses once the label was posted" do
      @client.cancel_result = Client::Rejected.new("Esse pedido não pode mais ser cancelado!")
      @client.info_result = @client.info(status: "posted")
      label = build_label(status: :purchased)

      error = assert_raises(Refused) { Cancel.new(label, client: @client).call }
      assert_match "já foi postada", error.message
      assert label.reload.purchased?
    end

    test "refuses after the shipment was marked as shipped" do
      label = build_label(status: :purchased)
      @shipment.mark_shipped!

      assert_raises(Refused) { Cancel.new(label, client: @client).call }
      assert_not @client.called?(:cancel)
    end

    # QA de 2026-11-05 (R1): o job morreu no meio e a etiqueta ficava presa,
    # sem botão e sem poder cancelar, bloqueando uma nova.
    test "cancels a label stuck before reaching SuperFrete without calling it" do
      label = build_label(status: :draft)

      Cancel.new(label, client: @client).call

      assert label.reload.cancelled?
      assert_empty @client.calls
      assert_not @shipment.shipping_labels.active.exists?
    end

    test "cancels a label stuck with an unpaid order at SuperFrete" do
      label = build_label(status: :cart_created)

      Cancel.new(label, client: @client).call

      assert label.reload.cancelled?
      assert @client.called?(:cancel)
    end

    test "keeps the label when SuperFrete does not answer" do
      @client.cancel_result = Client::Ambiguous.new("sem resposta")
      label = build_label(status: :purchased)

      assert_raises(Refused) { Cancel.new(label, client: @client).call }
      assert label.reload.purchased?
    end
  end
end
