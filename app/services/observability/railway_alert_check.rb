require "net/http"
require "json"

module Observability
  # Decisão de negócio (2026-09-24): sem plano Pro da Railway, não há
  # monitor nativo de CPU/RAM/erro — ver docs/architecture.md,
  # "Observabilidade". Reaproveita o mesmo relatório do painel
  # /admin/observability (RailwayMetricsReport) e envia ao Slack quando um
  # limiar é cruzado, sem infraestrutura nova.
  class RailwayAlertCheck
    CPU_THRESHOLD = 0.8
    MEMORY_THRESHOLD_GB = 1.0
    ERROR_RATE_THRESHOLD = 0.05

    def initialize(report: RailwayMetricsReport.new, webhook_url: ENV["SLACK_ALERT_WEBHOOK_URL"], http: nil)
      @report = report
      @webhook_url = webhook_url.to_s
      @http = http
    end

    def call
      return unless @webhook_url.present? && @report.configured?

      snapshot = @report.snapshot
      triggered = breaches(snapshot)
      return if triggered.empty?

      notify_slack(snapshot, triggered)
    rescue RailwayMetricsReport::ReportUnavailable
      nil
    end

    private

    def breaches(snapshot)
      [].tap do |list|
        list << "CPU em #{format_percentage(snapshot.cpu_usage)} (limite: #{format_percentage(CPU_THRESHOLD)})" if snapshot.cpu_usage.to_f > CPU_THRESHOLD
        list << "Memória em #{snapshot.memory_usage_gb.to_f.round(2)} GB (limite: #{MEMORY_THRESHOLD_GB} GB)" if snapshot.memory_usage_gb.to_f > MEMORY_THRESHOLD_GB
        list << "Taxa de erro em #{format_percentage(snapshot.error_rate)} (limite: #{format_percentage(ERROR_RATE_THRESHOLD)})" if snapshot.error_rate.to_f > ERROR_RATE_THRESHOLD
      end
    end

    def format_percentage(value)
      "#{(value.to_f * 100).round(1)}%"
    end

    def notify_slack(snapshot, triggered)
      body = {
        text: [
          ":rotating_light: *EloShop — métrica da Railway acima do limite*",
          *triggered.map { |line| "• #{line}" },
          "Consulte /admin/observability para o detalhe.",
          "_Amostra de #{snapshot.fetched_at.strftime('%d/%m %H:%M')}_"
        ].join("\n")
      }

      uri = URI(@webhook_url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      http(uri).request(request)
    rescue StandardError => e
      Rails.event.notify("observability.railway_alert_failed", error_class: e.class.name)
    end

    def http(uri)
      @http ||= Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.use_ssl = uri.scheme == "https"
        client.open_timeout = 5
        client.read_timeout = 5
      end
    end
  end
end
