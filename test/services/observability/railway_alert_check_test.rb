require "test_helper"

class Observability::RailwayAlertCheckTest < ActiveSupport::TestCase
  test "does nothing when no webhook URL is configured" do
    report = stub_report(snapshot: high_cpu_snapshot)
    fake_http = capturing_http

    Observability::RailwayAlertCheck.new(report: report, webhook_url: "", http: fake_http).call

    assert_nil fake_http.captured
  end

  test "does nothing when no threshold is breached" do
    report = stub_report(snapshot: healthy_snapshot)
    fake_http = capturing_http

    Observability::RailwayAlertCheck.new(report: report, webhook_url: "https://hooks.slack.test/x", http: fake_http).call

    assert_nil fake_http.captured
  end

  test "notifies Slack with every breached metric, without exposing the webhook URL as a credential" do
    report = stub_report(snapshot: high_cpu_snapshot)
    fake_http = capturing_http

    Observability::RailwayAlertCheck.new(report: report, webhook_url: "https://hooks.slack.test/x", http: fake_http).call

    body = JSON.parse(fake_http.captured.body)
    assert_includes body["text"], "CPU em 90.0%"
    assert_not_includes body["text"], "Memória"
    assert_not_includes body["text"], "Taxa de erro"
  end

  test "reports memory and error rate breaches independently" do
    report = stub_report(snapshot: overloaded_snapshot)
    fake_http = capturing_http

    Observability::RailwayAlertCheck.new(report: report, webhook_url: "https://hooks.slack.test/x", http: fake_http).call

    body = JSON.parse(fake_http.captured.body)
    assert_includes body["text"], "Memória em 1.5 GB"
    assert_includes body["text"], "Taxa de erro em 12.0%"
  end

  test "never raises when the report is unavailable" do
    report = Object.new
    report.define_singleton_method(:configured?) { true }
    report.define_singleton_method(:snapshot) { raise Observability::RailwayMetricsReport::ReportUnavailable, "boom" }

    assert_nothing_raised do
      Observability::RailwayAlertCheck.new(report: report, webhook_url: "https://hooks.slack.test/x").call
    end
  end

  test "never raises when the Slack webhook call itself fails" do
    report = stub_report(snapshot: high_cpu_snapshot)
    failing_http = Object.new
    failing_http.define_singleton_method(:request) { |_req| raise Timeout::Error, "slow" }

    assert_nothing_raised do
      Observability::RailwayAlertCheck.new(report: report, webhook_url: "https://hooks.slack.test/x", http: failing_http).call
    end
  end

  private

  def capturing_http
    Object.new.tap do |http|
      http.instance_variable_set(:@captured, nil)
      http.define_singleton_method(:captured) { @captured }
      http.define_singleton_method(:request) do |req|
        @captured = req
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.define_singleton_method(:body) { "ok" }
        response
      end
    end
  end

  def stub_report(snapshot:)
    Object.new.tap do |report|
      report.define_singleton_method(:configured?) { true }
      report.define_singleton_method(:snapshot) { snapshot }
    end
  end

  def healthy_snapshot
    Observability::RailwayMetricsReport::Snapshot.new(
      cpu_usage: 0.1, memory_usage_gb: 0.2, p50_ms: 10, p95_ms: 30, p99_ms: 50,
      error_rate: 0.0, total_requests: 100, fetched_at: Time.zone.parse("2026-09-24 12:00:00")
    )
  end

  def high_cpu_snapshot
    Observability::RailwayMetricsReport::Snapshot.new(
      cpu_usage: 0.9, memory_usage_gb: 0.2, p50_ms: 10, p95_ms: 30, p99_ms: 50,
      error_rate: 0.0, total_requests: 100, fetched_at: Time.zone.parse("2026-09-24 12:00:00")
    )
  end

  def overloaded_snapshot
    Observability::RailwayMetricsReport::Snapshot.new(
      cpu_usage: 0.1, memory_usage_gb: 1.5, p50_ms: 10, p95_ms: 30, p99_ms: 50,
      error_rate: 0.12, total_requests: 100, fetched_at: Time.zone.parse("2026-09-24 12:00:00")
    )
  end
end
