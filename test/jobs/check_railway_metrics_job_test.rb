require "test_helper"

class CheckRailwayMetricsJobTest < ActiveJob::TestCase
  test "runs without error when the Slack webhook is not configured" do
    original = ENV["SLACK_ALERT_WEBHOOK_URL"]
    ENV.delete("SLACK_ALERT_WEBHOOK_URL")

    assert_nothing_raised { CheckRailwayMetricsJob.perform_now }
  ensure
    ENV["SLACK_ALERT_WEBHOOK_URL"] = original
  end
end
