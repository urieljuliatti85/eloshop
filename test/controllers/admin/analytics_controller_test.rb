require "test_helper"

class Admin::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to login" do
    get admin_analytics_path

    assert_redirected_to new_session_path
  end

  test "shows the setup instructions when the reporting API is not configured" do
    sign_in_as(users(:one))

    with_env(
      "GOOGLE_ANALYTICS_PROPERTY_ID" => nil,
      "GOOGLE_ANALYTICS_CREDENTIALS_JSON" => nil,
      "GOOGLE_ANALYTICS_MEASUREMENT_ID" => nil
    ) do
      get admin_analytics_path
    end

    assert_response :success
    assert_select "h1", text: "Analytics"
    assert_select "a[aria-current='page']", text: "Analytics", minimum: 1
    assert_select "code", text: "GOOGLE_ANALYTICS_PROPERTY_ID"
    assert_select "code", text: "GOOGLE_ANALYTICS_CREDENTIALS_JSON"
    assert_select "code", text: "GOOGLE_ANALYTICS_MEASUREMENT_ID"
  end

  test "shows the aggregate report without exposing service account credentials" do
    snapshot = analytics_snapshot
    report = Object.new
    report.define_singleton_method(:configuration_issues) { [] }
    report.define_singleton_method(:configured?) { true }
    report.define_singleton_method(:snapshot) { snapshot }
    sign_in_as(users(:one))

    with_env(
      "GOOGLE_ANALYTICS_MEASUREMENT_ID" => "G-ABC123",
      "GOOGLE_ANALYTICS_CREDENTIALS_JSON" => "service-account-secret"
    ) do
      with_constructor_stub(Analytics::GoogleAnalyticsReport, report) { get admin_analytics_path }
    end

    assert_response :success
    assert_select ".admin-stat-value", text: "12"
    assert_select ".admin-stat-value", text: "18"
    assert_select ".admin-stat-value", text: "45"
    assert_select "td", text: "Catálogo"
    assert_not_includes response.body, "service-account-secret"
  end

  test "dashboard includes a compact analytics summary" do
    snapshot = analytics_snapshot
    report = Object.new
    report.define_singleton_method(:configured?) { true }
    report.define_singleton_method(:snapshot) { snapshot }
    sign_in_as(users(:one))

    with_constructor_stub(Analytics::GoogleAnalyticsReport, report) { get admin_root_path }

    assert_response :success
    assert_select "h2", text: "Últimos 30 dias"
    assert_select "a", text: "Abrir Analytics"
    assert_select ".admin-stat-value", text: "45"
  end

  private

  def analytics_snapshot
    Analytics::GoogleAnalyticsReport::Snapshot.new(
      active_users: 12,
      sessions: 18,
      page_views: 45,
      daily: [
        Analytics::GoogleAnalyticsReport::DailyPoint.new(date: Date.new(2026, 9, 22), active_users: 8, page_views: 21)
      ],
      top_pages: [
        Analytics::GoogleAnalyticsReport::PageRow.new(path: "/catalogo", title: "Catálogo", page_views: 20, active_users: 7)
      ],
      fetched_at: Time.zone.parse("2026-09-22 12:00:00")
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
