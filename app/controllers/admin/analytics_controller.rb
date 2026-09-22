module Admin
  class AnalyticsController < BaseController
    def index
      report = ::Analytics::GoogleAnalyticsReport.new
      @analytics_configuration_issues = report.configuration_issues
      @analytics_measurement_configured = helpers.google_analytics_measurement_id.present?
      @analytics_snapshot = report.snapshot if report.configured?
    rescue ::Analytics::GoogleAnalyticsReport::ReportUnavailable => e
      @analytics_error = e.message
    end
  end
end
