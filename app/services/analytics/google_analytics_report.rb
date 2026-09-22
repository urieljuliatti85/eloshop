require "google/analytics/data/v1beta"

module Analytics
  class GoogleAnalyticsReport
    class ReportUnavailable < StandardError; end

    CACHE_TTL = 15.minutes
    REPORT_DAYS = 30

    Snapshot = Data.define(:active_users, :sessions, :page_views, :daily, :top_pages, :fetched_at)
    DailyPoint = Data.define(:date, :active_users, :page_views)
    PageRow = Data.define(:path, :title, :page_views, :active_users)

    def initialize(
      property_id: ENV["GOOGLE_ANALYTICS_PROPERTY_ID"],
      credentials_json: ENV["GOOGLE_ANALYTICS_CREDENTIALS_JSON"],
      client: nil
    )
      @property_id = property_id.to_s.strip
      @credentials_json = credentials_json.to_s
      @client = client
    end

    def configured?
      configuration_issues.empty?
    end

    def configuration_issues
      issues = []
      issues << "GOOGLE_ANALYTICS_PROPERTY_ID" unless property_id.match?(/\A\d+\z/)
      issues << "GOOGLE_ANALYTICS_CREDENTIALS_JSON" unless valid_credentials?
      issues
    end

    def snapshot
      raise ReportUnavailable, "A integração com o Google Analytics ainda não está configurada." unless configured?

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_snapshot }
    rescue ReportUnavailable
      raise
    rescue StandardError => e
      Rails.event.notify("admin.google_analytics.report_failed", error_class: e.class.name)
      raise ReportUnavailable, "Não foi possível consultar o Google Analytics agora. Tente novamente em alguns minutos."
    end

    private

    attr_reader :property_id, :credentials_json

    def cache_key
      "admin/google_analytics/v1/#{property_id}/#{REPORT_DAYS}days"
    end

    def valid_credentials?
      credentials = parsed_credentials
      credentials.is_a?(Hash) &&
        credentials["type"] == "service_account" &&
        credentials["client_email"].present? &&
        credentials["private_key"].present?
    rescue JSON::ParserError
      false
    end

    def parsed_credentials
      @parsed_credentials ||= JSON.parse(credentials_json)
    end

    def analytics_client
      @client ||= Google::Analytics::Data::V1beta::AnalyticsData::Client.new do |config|
        # A origem é uma variável privada da Railway, não entrada de usuário.
        # O hash evita depender de um arquivo efêmero dentro do container.
        config.credentials = parsed_credentials
      end
    end

    def fetch_snapshot
      summary = run_report(metrics: %w[activeUsers sessions screenPageViews])
      daily = run_report(
        dimensions: %w[date],
        metrics: %w[activeUsers screenPageViews],
        order_bys: [ { dimension: { dimension_name: "date" } } ]
      )
      pages = run_report(
        dimensions: %w[pagePath pageTitle],
        metrics: %w[screenPageViews activeUsers],
        order_bys: [ { metric: { metric_name: "screenPageViews" }, desc: true } ],
        limit: 10
      )

      summary_values = metric_values(summary.rows.first, 3)
      Snapshot.new(
        active_users: summary_values[0],
        sessions: summary_values[1],
        page_views: summary_values[2],
        daily: daily_rows(daily),
        top_pages: page_rows(pages),
        fetched_at: Time.current
      )
    end

    def run_report(dimensions: [], metrics:, order_bys: [], limit: nil)
      request = {
        property: "properties/#{property_id}",
        date_ranges: [ { start_date: "#{REPORT_DAYS}daysAgo", end_date: "today" } ],
        dimensions: dimensions.map { |name| { name: name } },
        metrics: metrics.map { |name| { name: name } },
        order_bys: order_bys
      }
      request[:limit] = limit if limit

      analytics_client.run_report(request, timeout: 5)
    end

    def daily_rows(response)
      response.rows.map do |row|
        values = metric_values(row, 2)
        DailyPoint.new(
          date: Date.strptime(row.dimension_values.first.value, "%Y%m%d"),
          active_users: values[0],
          page_views: values[1]
        )
      end
    end

    def page_rows(response)
      response.rows.map do |row|
        values = metric_values(row, 2)
        PageRow.new(
          path: row.dimension_values[0].value,
          title: row.dimension_values[1].value.presence || row.dimension_values[0].value,
          page_views: values[0],
          active_users: values[1]
        )
      end
    end

    def metric_values(row, count)
      return Array.new(count, 0) unless row

      values = row.metric_values.first(count).map { |value| value.value.to_i }
      values + Array.new(count - values.length, 0)
    end
  end
end
