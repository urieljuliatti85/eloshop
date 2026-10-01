require "test_helper"

module Analytics
  class SellerConnectionReportTest < ActiveSupport::TestCase
    test "counts clicks, completions and failures in the period, with the rate and who each belongs to" do
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_started", seller: sellers(:pending))
      Funnel.track("seller_mp_connect_started", seller: sellers(:other))
      Funnel.track("seller_mp_connect_completed", seller: sellers(:approved))
      Funnel.track("seller_mp_connect_failed", seller: sellers(:pending))
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved), occurred_at: 40.days.ago)

      snapshot = FunnelReport.new.seller_connection_snapshot

      assert_equal 4, snapshot.started
      assert_equal 1, snapshot.completed
      assert_equal 1, snapshot.failed
      assert_equal 25.0, snapshot.completion_rate
      assert_equal [ "Ateliê Pendente", "EloShop", "Outro Ateliê" ].sort, snapshot.started_by.map { |entry| entry.seller.name }.sort
      assert_equal [ sellers(:approved) ], snapshot.completed_by.map(&:seller)
      assert_equal [ sellers(:pending) ], snapshot.failed_by.map(&:seller)
      assert_equal 2, snapshot.started_by.find { |entry| entry.seller == sellers(:approved) }.count
    end

    test "lists the most recent seller first and keeps the buyer funnel untouched" do
      Funnel.track("seller_mp_connect_started", seller: sellers(:approved), occurred_at: 3.days.ago)
      Funnel.track("seller_mp_connect_started", seller: sellers(:other), occurred_at: 1.day.ago)

      snapshot = FunnelReport.new.seller_connection_snapshot

      assert_equal [ sellers(:other), sellers(:approved) ], snapshot.started_by.map(&:seller)
      assert_equal FunnelEvent::BUYER_EVENT_NAMES.sort, FunnelReport.new.snapshot.counts.keys.sort
    end

    test "has a zero rate and empty lists when nobody clicked" do
      snapshot = FunnelReport.new.seller_connection_snapshot

      assert_equal 0.0, snapshot.completion_rate
      assert_empty snapshot.started_by
      assert_empty snapshot.failed_by
    end

    test "rejects an unknown event name" do
      assert_raises(Funnel::InvalidEvent) { Funnel.track("seller_mp_connect_typo") }
    end
  end
end
