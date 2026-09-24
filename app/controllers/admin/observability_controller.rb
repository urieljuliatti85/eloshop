module Admin
  class ObservabilityController < BaseController
    def index
      report = ::Observability::RailwayMetricsReport.new
      @railway_configuration_issues = report.configuration_issues
      @railway_snapshot = report.snapshot if report.configured?
    rescue ::Observability::RailwayMetricsReport::ReportUnavailable => e
      @railway_error = e.message
    end
  end
end
