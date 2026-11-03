require "test_helper"

class ReturnRequestTest < ActiveSupport::TestCase
  setup do
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @customer = customers(:one)
    @admin = users(:one)
  end

  test "the protocol comes from the database, derived from the id, right on insert" do
    return_request = open_request

    assert_equal "ELO-#{return_request.created_at.year}-#{return_request.id.to_s.rjust(6, '0')}", return_request.protocol
  end

  test "two requests never share a protocol" do
    first = open_request(kind: :withdrawal)
    second = open_request(kind: :product_issue)

    refute_equal first.protocol, second.protocol
  end

  test "responds in two business days, skipping the weekend" do
    assert_equal Date.new(2026, 11, 5), ReturnRequest.respond_by_for(Time.zone.parse("2026-11-03 09:00")) # terça → quinta
    assert_equal Date.new(2026, 11, 10), ReturnRequest.respond_by_for(Time.zone.parse("2026-11-06 17:00")) # sexta → terça
    assert_equal Date.new(2026, 11, 10), ReturnRequest.respond_by_for(Time.zone.parse("2026-11-07 10:00")) # sábado → terça
    assert_equal Date.new(2026, 11, 10), ReturnRequest.respond_by_for(Time.zone.parse("2026-11-08 23:59")) # domingo → terça
  end

  test "the database refuses a second open request of the same kind for the same order" do
    open_request(kind: :withdrawal)

    assert_raises(ActiveRecord::RecordNotUnique) do
      @seller_order.return_requests.create!(kind: :withdrawal, respond_by: Date.current)
    end
  end

  test "a new request of the same kind is allowed once the previous one is closed" do
    first = open_request(kind: :withdrawal)
    first.record_update!(author: @admin, new_status: "closed")

    assert_nothing_raised { open_request(kind: :withdrawal) }
  end

  test "records the admin answer and the status change in the history" do
    return_request = open_request

    update = return_request.record_update!(author: @admin, body: "Vamos reembolsar.", new_status: "in_progress")

    assert_predicate return_request.reload, :in_progress?
    assert_equal "received", update.from_status
    assert_equal "in_progress", update.to_status
    assert_equal "Vamos reembolsar.", update.body
  end

  test "refuses invalid transitions and leaves no history behind" do
    return_request = open_request
    return_request.record_update!(author: @admin, new_status: "resolved")

    assert_no_difference -> { return_request.updates.count } do
      assert_raises(ReturnRequest::InvalidStatusTransition) do
        return_request.record_update!(author: @admin, body: "Reabrindo", new_status: "in_progress")
      end
    end
    assert_predicate return_request.reload, :resolved?
    assert_not_nil return_request.resolved_at
  end

  test "an update with neither answer nor new status records nothing" do
    return_request = open_request

    assert_nil return_request.record_update!(author: @admin, body: "  ", new_status: "")
    assert_nil return_request.record_update!(author: @admin, new_status: "received")
  end

  test "only paid orders not fully refunded are eligible" do
    assert ReturnRequest.eligible?(@seller_order)

    @seller_order.update!(status: :partially_refunded)
    assert ReturnRequest.eligible?(@seller_order)

    %w[pending cancelled refunded].each do |status|
      @seller_order.update!(status: status)
      refute ReturnRequest.eligible?(@seller_order), status
    end
  end

  test "an open kind leaves the list of kinds the buyer can still open, and an open withdrawal empties it" do
    assert_equal ReturnRequest.kinds.keys, ReturnRequest.available_kinds(@seller_order)

    open_request(kind: :delivery_issue)
    assert_equal %w[withdrawal product_issue], ReturnRequest.available_kinds(@seller_order)

    withdrawal = open_request(kind: :withdrawal)
    assert_empty ReturnRequest.available_kinds(@seller_order)

    withdrawal.record_update!(author: @admin, new_status: "closed")
    assert_equal %w[withdrawal product_issue], ReturnRequest.available_kinds(@seller_order)
  end

  test "an unpaid order has no kinds available" do
    @seller_order.update!(status: :pending)

    assert_empty ReturnRequest.available_kinds(@seller_order)
  end

  test "the withdrawal window is informative and unknown without a delivery date" do
    return_request = open_request(kind: :withdrawal)
    assert_nil return_request.within_withdrawal_window?

    shipment = @seller_order.create_shipment!(carrier: "Correios", service: "PAC", shipping_cents: 1_500, estimated_days: 5)
    shipment.update_columns(status: "delivered", delivered_at: 3.days.ago)
    assert return_request.reload.within_withdrawal_window?

    shipment.update_columns(delivered_at: 30.days.ago)
    refute return_request.reload.within_withdrawal_window?
  end

  test "overdue only while open and past the deadline" do
    return_request = open_request
    return_request.update_columns(respond_by: Date.current - 1)

    assert_predicate return_request, :overdue?
    return_request.record_update!(author: @admin, new_status: "closed")
    refute_predicate return_request.reload, :overdue?
  end

  private

  def open_request(kind: :withdrawal)
    ReturnRequests::Open.new(seller_order: @seller_order, customer: @customer, kind: kind).call.return_request
  end
end
