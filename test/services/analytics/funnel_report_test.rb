require "test_helper"

class Analytics::FunnelReportTest < ActiveSupport::TestCase
  setup { FunnelEvent.delete_all }

  test "calcula contagens, receita e taxas do período" do
    date = Date.current
    FunnelEvent.create!(event_name: "view_catalog", occurred_on: date, event_count: 10)
    FunnelEvent.create!(event_name: "view_product", occurred_on: date, event_count: 10)
    FunnelEvent.create!(event_name: "checkout_started", occurred_on: date, event_count: 4)
    FunnelEvent.create!(event_name: "order_confirmed", occurred_on: date, event_count: 2, amount_cents: 12_500)

    snapshot = Analytics::FunnelReport.new.snapshot

    assert_equal 20, snapshot.counts["view_catalog"] + snapshot.counts["view_product"]
    assert_equal 12_500, snapshot.confirmed_revenue_cents
    assert_equal 10.0, snapshot.conversion_rate
    assert_equal 50.0, snapshot.checkout_conversion_rate
  end
end
