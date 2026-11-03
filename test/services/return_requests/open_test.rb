require "test_helper"

class ReturnRequests::OpenTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @customer = customers(:one)
  end

  test "opens the request with the whole order, the opening history and the order event" do
    result = open(kind: :withdrawal, description: "Não quero mais.")
    return_request = result.return_request

    assert result.created
    assert_predicate return_request, :received?
    assert_match(/\AELO-\d{4}-\d{6}\z/, return_request.protocol)
    assert_equal @seller_order.order_items.map { |item| [ item.id, item.quantity ] }.sort,
      return_request.items.map { |item| [ item.order_item_id, item.quantity ] }.sort
    opening = return_request.updates.sole
    assert_equal @customer, opening.author
    assert_equal "received", opening.to_status
    assert_equal "Não quero mais.", opening.body
    event = @seller_order.order.order_events.find_by!(kind: "return_request_opened")
    assert_equal return_request.protocol, event.metadata["protocol"]
  end

  test "e-mails the protocol to the buyer and notifies admins and the atelier" do
    assert_enqueued_emails 1 do
      assert_difference -> { Notification.where(kind: "return_request_opened").count }, User.admin.count + 1 do
        open(kind: :withdrawal)
      end
    end
    seller_notification = Notification.find_by!(recipient: @seller_order.seller, kind: "return_request_opened")
    assert_match "Não envie a peça", seller_notification.body
  end

  test "never refuses a withdrawal because production started or the delivery is old" do
    @seller_order.update!(production_started_at: 20.days.ago)
    shipment = @seller_order.create_shipment!(carrier: "Correios", service: "PAC", shipping_cents: 1_500, estimated_days: 5)
    shipment.update_columns(status: "delivered", delivered_at: 60.days.ago)

    assert open(kind: :withdrawal).created
  end

  test "a second request of the same kind while one is open joins the open one" do
    first = open(kind: :withdrawal).return_request

    assert_no_difference -> { ReturnRequest.count } do
      assert_no_enqueued_emails do
        result = open(kind: :withdrawal, description: "Também a outra peça.")
        refute result.created
        assert_equal first, result.return_request
      end
    end
    assert_equal "Também a outra peça.", first.updates.chronological.last.body
  end

  test "different kinds open separate requests" do
    withdrawal = open(kind: :withdrawal).return_request
    issue = open(kind: :delivery_issue).return_request

    refute_equal withdrawal, issue
  end

  test "refuses unpaid or fully refunded orders" do
    %w[pending refunded].each do |status|
      @seller_order.update!(status: status)
      assert_raises(ReturnRequests::Open::NotEligible) { open(kind: :withdrawal) }
    end
    assert_equal 0, ReturnRequest.count
  end

  test "refuses an unknown kind" do
    assert_raises(ReturnRequests::Open::NotEligible) { open(kind: "refund_everything") }
  end

  private

  def open(kind:, description: nil)
    ReturnRequests::Open.new(seller_order: @seller_order, customer: @customer, kind: kind, description: description).call
  end
end
