require "test_helper"

module ShippingLabels
  class TrackTest < ActiveSupport::TestCase
    include ShippingLabelTestHelper
    include ActiveJob::TestHelper

    setup do
      prepare_label_scenario
      @label = build_label(status: :purchased, tracking_code: "AA123456789BR", purchased_at: Time.current)
    end

    test "posted marks the shipment as shipped with the label's tracking code and tells the buyer once" do
      assert_enqueued_with(job: NotifyCustomerOfShipmentJob) do
        assert_difference -> { Notification.where(kind: :order_shipped).count }, 1 do
          Track.new(@label).apply(status: "posted", tracking: "AA123456789BR")
        end
      end

      assert @shipment.reload.shipped?
      assert_equal "AA123456789BR", @shipment.tracking_code
      assert_equal "PAC", @shipment.service
      assert @label.reload.posted_at.present?
      assert_equal "posted", @label.provider_status

      assert_no_difference -> { Notification.count } do
        Track.new(@label.reload).apply(status: "posted")
      end
    end

    test "delivered closes the shipment even when posted never arrived, saying the carrier confirmed" do
      Track.new(@label).apply(status: "delivered", tracking: "AA123456789BR")

      assert @shipment.reload.delivered?
      assert @label.reload.delivered_at.present?
      assert @label.posted_at.present?
      delivered = Notification.find_by!(kind: :order_delivered)
      assert_match "transportadora confirmou", delivered.body
      assert_enqueued_with(job: NotifyCustomerOfDeliveryJob, args: [ @seller_order, { by_carrier: true } ])
    end

    test "a late posted after delivered changes nothing" do
      Track.new(@label).apply(status: "delivered")

      assert_no_difference -> { Notification.count } do
        Track.new(@label.reload).apply(status: "posted")
      end
      assert @shipment.reload.delivered?
      assert_equal "delivered", @label.reload.provider_status
    end

    test "posted with an open withdrawal keeps the shipment, records the posting and warns once" do
      ReturnRequests::Open.new(seller_order: @seller_order, customer: customers(:one), kind: :withdrawal).call

      assert_enqueued_jobs 1, only: NotifyShippingLabelAttentionJob do
        Track.new(@label).apply(status: "posted")
        Track.new(@label.reload).apply(status: "delivered")
      end

      assert @shipment.reload.pending?
      assert @label.reload.posted_at.present?
      assert @label.delivered_at.present?
      assert @label.attention_notified_at.present?
      assert_equal 0, Notification.where(kind: %i[order_shipped order_delivered]).count
    end

    test "a tracking code already used by another shipment does not stop the shipment" do
      other_order = SellerOrder.where.not(id: @seller_order.id).first
      skip "precisa de outro pedido nas fixtures" unless other_order
      Shipment.create!(seller_order: other_order, carrier: "Correios", service: "PAC", shipping_cents: 1500, estimated_days: 5, tracking_code: "AA123456789BR")

      Track.new(@label).apply(status: "posted")

      assert @shipment.reload.shipped?
      assert_nil @shipment.tracking_code
    end

    test "the shipment already marked by the seller is left as it is" do
      @shipment.mark_shipped!(tracking_code: "BB987654321BR")

      assert_no_difference -> { Notification.count } do
        Track.new(@label).apply(status: "posted")
      end
      assert_equal "BB987654321BR", @shipment.reload.tracking_code
    end

    test "cancelled at SuperFrete before posting cancels the label" do
      Track.new(@label).apply(status: "canceled")

      assert @label.reload.cancelled?
      assert @shipment.reload.pending?
    end

    test "a paid status for a label still being confirmed hands over to the purchase" do
      label = @label
      label.update_columns(status: "purchasing")

      assert_enqueued_with(job: PurchaseShippingLabelJob, args: [ label ]) do
        assert_equal :reconciling, Track.new(label).apply(status: "released")
      end
    end

    test "draft and failed labels are ignored" do
      @label.update_columns(status: "failed")

      assert_equal :ignored, Track.new(@label).apply(status: "posted")
      assert @shipment.reload.pending?
    end
  end
end
