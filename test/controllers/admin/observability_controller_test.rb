require "test_helper"

class Admin::ObservabilityControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to login" do
    get admin_observability_path

    assert_redirected_to new_session_path
  end

  test "shows the setup instructions when the Railway API is not configured" do
    sign_in_as(users(:one))

    with_env(
      "RAILWAY_API_TOKEN" => nil,
      "RAILWAY_PROJECT_ID" => nil,
      "RAILWAY_SERVICE_ID" => nil,
      "RAILWAY_ENVIRONMENT_ID" => nil
    ) do
      get admin_observability_path
    end

    assert_response :success
    assert_select "h1", text: "Observabilidade"
    assert_select "a[aria-current='page']", text: "Observabilidade", minimum: 1
    assert_select "code", text: "RAILWAY_API_TOKEN"
    assert_select "code", text: "RAILWAY_PROJECT_ID"
    assert_select "code", text: "RAILWAY_SERVICE_ID"
    assert_select "code", text: "RAILWAY_ENVIRONMENT_ID"
  end

  test "shows the metrics snapshot without exposing the API token" do
    snapshot = railway_snapshot
    report = Object.new
    report.define_singleton_method(:configuration_issues) { [] }
    report.define_singleton_method(:configured?) { true }
    report.define_singleton_method(:snapshot) { snapshot }
    sign_in_as(users(:one))

    with_env("RAILWAY_API_TOKEN" => "railway-secret-token") do
      with_constructor_stub(Observability::RailwayMetricsReport, report) { get admin_observability_path }
    end

    assert_response :success
    assert_select ".admin-stat-value", text: "12,0%"
    assert_not_includes response.body, "railway-secret-token"
  end

  test "shows a safe error message when the report cannot be fetched" do
    report = Object.new
    report.define_singleton_method(:configuration_issues) { [] }
    report.define_singleton_method(:configured?) { true }
    report.define_singleton_method(:snapshot) { raise Observability::RailwayMetricsReport::ReportUnavailable, "erro genérico" }
    sign_in_as(users(:one))

    with_constructor_stub(Observability::RailwayMetricsReport, report) { get admin_observability_path }

    assert_response :success
    assert_select "h2", text: "Não foi possível atualizar os dados"
  end

  private

  def railway_snapshot
    Observability::RailwayMetricsReport::Snapshot.new(
      cpu_usage: 0.12,
      memory_usage_gb: 0.19,
      p50_ms: 45,
      p95_ms: 320,
      p99_ms: 610,
      error_rate: 0.0,
      total_requests: 120,
      fetched_at: Time.zone.parse("2026-09-24 12:00:00")
    )
  end

  def with_constructor_stub(klass, instance)
    original_constructor = klass.method(:new)
    klass.define_singleton_method(:new) { |*| instance }
    yield
  ensure
    klass.define_singleton_method(:new, original_constructor)
  end

  def with_env(values)
    original_values = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original_values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
