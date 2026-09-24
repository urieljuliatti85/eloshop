require "test_helper"

class Observability::RailwayMetricsReportTest < ActiveSupport::TestCase
  test "reports missing configuration without exposing the token" do
    report = Observability::RailwayMetricsReport.new(token: "", project_id: "", service_id: "", environment_id: "")

    assert_not report.configured?
    assert_equal %w[RAILWAY_API_TOKEN RAILWAY_PROJECT_ID RAILWAY_SERVICE_ID RAILWAY_ENVIRONMENT_ID], report.configuration_issues
  end

  test "returns and caches the snapshot" do
    responses = [
      graphql_response("metrics" => [
        { "measurement" => "CPU_USAGE", "values" => [ { "ts" => 1, "value" => 0.05 }, { "ts" => 2, "value" => 0.12 } ] },
        { "measurement" => "MEMORY_USAGE_GB", "values" => [ { "ts" => 1, "value" => 0.14 }, { "ts" => 2, "value" => 0.19 } ] }
      ]),
      graphql_response("httpDurationMetrics" => { "samples" => [
        { "p50" => 20, "p90" => 100, "p95" => 200, "p99" => 300, "ts" => 1 },
        { "p50" => 45, "p90" => 250, "p95" => 320, "p99" => 610, "ts" => 2 }
      ] }),
      graphql_response("httpMetricsGroupedByStatus" => [
        { "statusCode" => 200, "samples" => [ { "value" => 118 } ] },
        { "statusCode" => 500, "samples" => [ { "value" => 2 } ] }
      ])
    ]
    report = configured_report(responses)

    snapshot = report.snapshot
    cached_snapshot = report.snapshot

    assert_equal 0.12, snapshot.cpu_usage
    assert_equal 0.19, snapshot.memory_usage_gb
    assert_equal 45, snapshot.p50_ms
    assert_equal 320, snapshot.p95_ms
    assert_equal 610, snapshot.p99_ms
    assert_in_delta 0.0166, snapshot.error_rate, 0.001
    assert_equal 120, snapshot.total_requests
    assert_equal snapshot, cached_snapshot
  end

  test "turns a GraphQL error response into a safe error for the admin" do
    responses = [ graphql_error("Not Authorized") ]
    report = configured_report(responses)

    error = assert_raises(Observability::RailwayMetricsReport::ReportUnavailable) { report.snapshot }

    assert_equal "Não foi possível consultar as métricas da Railway agora. Tente novamente em alguns minutos.", error.message
  end

  test "sends the token only in the Authorization header, never in the body" do
    captured = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |req|
      captured ||= req
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:body) do
        { data: { metrics: [], httpDurationMetrics: { samples: [] }, httpMetricsGroupedByStatus: [] } }.to_json
      end
      response
    end

    report = Observability::RailwayMetricsReport.new(
      token: "secret-token", project_id: "p", service_id: "s", environment_id: "e", http: fake_http
    )
    report.snapshot

    assert_equal "Bearer secret-token", captured["Authorization"]
    assert_not_includes captured.body, "secret-token"
  end

  private

  def configured_report(responses)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |_req|
      response = Net::HTTPOK.new("1.1", "200", "OK")
      body = responses.shift
      response.define_singleton_method(:body) { body }
      response
    end

    Observability::RailwayMetricsReport.new(
      token: "token", project_id: "project-1", service_id: "service-1", environment_id: "env-1", http: fake_http
    )
  end

  def graphql_response(data)
    { data: data }.to_json
  end

  def graphql_error(message)
    { errors: [ { message: message } ] }.to_json
  end
end
