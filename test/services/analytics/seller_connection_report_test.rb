require "test_helper"

module Analytics
  class SellerConnectionReportTest < ActiveSupport::TestCase
    test "counts clicks and completions in the period, with the completion rate and distinct sellers" do
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_started", seller: sellers(:pending))
      Funnel.track("seller_mp_connect_started", seller: sellers(:other))
      Funnel.track("seller_mp_connect_completed", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved), occurred_at: 40.days.ago)

      snapshot = FunnelReport.new.seller_connection_snapshot

      assert_equal 4, snapshot.started
      assert_equal 1, snapshot.completed
      assert_equal 25.0, snapshot.completion_rate
      assert_equal 3, snapshot.sellers_started
      assert_equal 1, snapshot.sellers_completed
    end

    test "has a zero rate when nobody clicked, and keeps the buyer funnel untouched" do
      snapshot = FunnelReport.new.seller_connection_snapshot
      assert_equal 0.0, snapshot.completion_rate

      Funnel.track("seller_mp_connect_started", seller: sellers(:approved))
      assert_equal FunnelEvent::BUYER_EVENT_NAMES.sort, FunnelReport.new.snapshot.counts.keys.sort
    end

    test "rejects an unknown event name" do
      assert_raises(Funnel::InvalidEvent) { Funnel.track("seller_mp_connect_typo") }
    end
  end
end
