require "test_helper"

class Analytics::GoogleAnalyticsReportTest < ActiveSupport::TestCase
  Value = Data.define(:value)
  Row = Data.define(:dimension_values, :metric_values)
  Response = Data.define(:rows)

  class FakeClient
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def run_report(request, timeout:)
      requests << { request: request, timeout: timeout }
      response = @responses.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  test "reports missing or invalid configuration without exposing credential contents" do
    report = Analytics::GoogleAnalyticsReport.new(property_id: "abc", credentials_json: "not-json")

    assert_not report.configured?
    assert_equal %w[GOOGLE_ANALYTICS_PROPERTY_ID GOOGLE_ANALYTICS_CREDENTIALS_JSON], report.configuration_issues
  end

  test "rejects valid JSON that is not a service account object" do
    report = Analytics::GoogleAnalyticsReport.new(property_id: "123456", credentials_json: '"hello"')

    assert_not report.configured?
    assert_equal [ "GOOGLE_ANALYTICS_CREDENTIALS_JSON" ], report.configuration_issues
  end

  test "returns and caches the thirty day snapshot" do
    client = FakeClient.new([
      response(row(metrics: %w[12 18 45])),
      response(row(dimensions: [ "20260922" ], metrics: %w[8 21])),
      response(row(dimensions: [ "/catalogo", "Catálogo" ], metrics: %w[20 7]))
    ])
    report = configured_report(client)

    snapshot = report.snapshot
    cached_snapshot = report.snapshot

    assert_equal 12, snapshot.active_users
    assert_equal 18, snapshot.sessions
    assert_equal 45, snapshot.page_views
    assert_equal Date.new(2026, 9, 22), snapshot.daily.first.date
    assert_equal 21, snapshot.daily.first.page_views
    assert_equal "/catalogo", snapshot.top_pages.first.path
    assert_equal 20, snapshot.top_pages.first.page_views
    assert_equal snapshot, cached_snapshot
    assert_equal 3, client.requests.length
    assert_equal "properties/123456", client.requests.first[:request][:property]
    assert_equal 5, client.requests.first[:timeout]
  end

  test "turns provider failures into a safe error for the admin" do
    client = FakeClient.new([ StandardError.new("secret provider detail") ])

    error = assert_raises(Analytics::GoogleAnalyticsReport::ReportUnavailable) do
      configured_report(client).snapshot
    end

    assert_equal "Não foi possível consultar o Google Analytics agora. Tente novamente em alguns minutos.", error.message
    assert_not_includes error.message, "secret provider detail"
  end

  private

  def configured_report(client)
    Analytics::GoogleAnalyticsReport.new(
      property_id: "123456",
      credentials_json: {
        type: "service_account",
        client_email: "analytics@example.test",
        private_key: "private-key"
      }.to_json,
      client: client
    )
  end

  def response(*rows)
    Response.new(rows: rows)
  end

  def row(dimensions: [], metrics: [])
    Row.new(
      dimension_values: dimensions.map { |value| Value.new(value: value) },
      metric_values: metrics.map { |value| Value.new(value: value) }
    )
  end
end
