require "test_helper"

class GoogleAnalyticsTrackingTest < ActionDispatch::IntegrationTest
  test "offers consent on an allowlisted public page using only a virtual path" do
    with_measurement_id("G-ABC123") { get root_path }

    assert_response :success
    assert_select "body[data-controller='google-analytics']"
    assert_select "body[data-google-analytics-page-path-value='/inicio']"
    assert_select "[data-google-analytics-target='banner']", text: /Métricas de uso/
    assert_select "body[data-google-analytics-page-path-value='/']", count: 0
  end

  test "does not install analytics on cart checkout account or admin surfaces" do
    with_measurement_id("G-ABC123") { get cart_path }

    assert_response :success
    assert_select "body[data-controller='google-analytics']", count: 0
    assert_select "[data-google-analytics-target='banner']", count: 0

    sign_in_as(users(:one))
    with_measurement_id("G-ABC123") { get admin_root_path }

    assert_response :success
    assert_select "body[data-controller='google-analytics']", count: 0
    assert_not_includes response.body, "G-ABC123"
  end

  test "ignores an invalid measurement id" do
    with_measurement_id("not-a-measurement-id") { get root_path }

    assert_response :success
    assert_select "body[data-controller='google-analytics']", count: 0
  end

  private

  def with_measurement_id(value)
    original = ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"]
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = value
    yield
  ensure
    original.nil? ? ENV.delete("GOOGLE_ANALYTICS_MEASUREMENT_ID") : ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = original
  end
end
