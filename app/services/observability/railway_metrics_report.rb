require "net/http"
require "json"

module Observability
  # Métricas de infraestrutura e HTTP da própria Railway — sem gem de APM
  # nem serviço adicional (Prometheus/Grafana avaliados e descartados por
  # redundância com o que a Railway já expõe nativamente via API, ver
  # docs/architecture.md, "Observabilidade"). Mesmo padrão de
  # Analytics::GoogleAnalyticsReport: configuração opcional, cache curto,
  # degrada para um aviso em vez de derrubar o dashboard.
  class RailwayMetricsReport
    class ReportUnavailable < StandardError; end

    API_ENDPOINT = "https://backboard.railway.com/graphql/v2"
    CACHE_TTL = 15.minutes
    REQUEST_TIMEOUT = 5

    Snapshot = Data.define(:cpu_usage, :memory_usage_gb, :p50_ms, :p95_ms, :p99_ms, :error_rate, :total_requests, :fetched_at)

    def initialize(
      token: ENV["RAILWAY_API_TOKEN"],
      project_id: ENV["RAILWAY_PROJECT_ID"],
      service_id: ENV["RAILWAY_SERVICE_ID"],
      environment_id: ENV["RAILWAY_ENVIRONMENT_ID"],
      http: nil
    )
      @token = token.to_s
      @project_id = project_id.to_s
      @service_id = service_id.to_s
      @environment_id = environment_id.to_s
      @http = http
    end

    def configured?
      configuration_issues.empty?
    end

    # PROJECT_ID/SERVICE_ID/ENVIRONMENT_ID são injetadas automaticamente pela
    # Railway em todo serviço — só o token precisa ser criado e configurado
    # manualmente (Project Settings → Tokens, escopado ao ambiente de
    # produção). A checagem das três primeiras é defensiva, para o caso de
    # rodar fora da Railway (ex.: local).
    def configuration_issues
      issues = []
      issues << "RAILWAY_API_TOKEN" if @token.blank?
      issues << "RAILWAY_PROJECT_ID" if @project_id.blank?
      issues << "RAILWAY_SERVICE_ID" if @service_id.blank?
      issues << "RAILWAY_ENVIRONMENT_ID" if @environment_id.blank?
      issues
    end

    def snapshot
      raise ReportUnavailable, "A integração com as métricas da Railway ainda não está configurada." unless configured?

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_snapshot }
    rescue ReportUnavailable
      raise
    rescue StandardError => e
      Rails.event.notify("admin.railway_metrics.report_failed", error_class: e.class.name)
      raise ReportUnavailable, "Não foi possível consultar as métricas da Railway agora. Tente novamente em alguns minutos."
    end

    private

    def cache_key
      "admin/railway_metrics/v1/#{@service_id}/#{@environment_id}"
    end

    def fetch_snapshot
      usage = latest_usage(request_metrics)
      response = request_http_metrics

      Snapshot.new(
        cpu_usage: usage[:cpu],
        memory_usage_gb: usage[:memory_gb],
        p50_ms: response[:p50],
        p95_ms: response[:p95],
        p99_ms: response[:p99],
        error_rate: response[:error_rate],
        total_requests: response[:total_requests],
        fetched_at: Time.current
      )
    end

    # `metrics` devolve séries por measurement (CPU_USAGE, MEMORY_USAGE_GB);
    # usamos só o ponto mais recente de cada uma para o cartão de "agora".
    def request_metrics
      query = <<~GRAPHQL
        query($serviceId: String!, $environmentId: String!) {
          metrics(serviceId: $serviceId, environmentId: $environmentId) {
            measurement
            values { ts value }
          }
        }
      GRAPHQL

      graphql_request(query, serviceId: @service_id, environmentId: @environment_id)
    end

    def latest_usage(payload)
      series = payload.dig("data", "metrics") || []
      cpu = series.find { |serie| serie["measurement"] == "CPU_USAGE" }
      memory = series.find { |serie| serie["measurement"] == "MEMORY_USAGE_GB" }

      { cpu: last_value(cpu), memory_gb: last_value(memory) }
    end

    def last_value(serie)
      serie&.dig("values")&.last&.dig("value")
    end

    # `httpMetrics` cobre p50/p95/p99 de latência e taxa de erro da última
    # hora — o mesmo dado que o dashboard "Observability" da Railway mostra,
    # só que consultado programaticamente.
    def request_http_metrics
      query = <<~GRAPHQL
        query($serviceId: String!, $environmentId: String!) {
          httpMetrics(serviceId: $serviceId, environmentId: $environmentId, hoursBack: 1) {
            p50 p95 p99
            errorRate
            totalRequests
          }
        }
      GRAPHQL

      payload = graphql_request(query, serviceId: @service_id, environmentId: @environment_id)
      metrics = payload.dig("data", "httpMetrics") || {}

      {
        p50: metrics["p50"],
        p95: metrics["p95"],
        p99: metrics["p99"],
        error_rate: metrics["errorRate"],
        total_requests: metrics["totalRequests"]
      }
    end

    def graphql_request(query, **variables)
      uri = URI(API_ENDPOINT)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@token}"
      request.body = { query: query, variables: variables }.to_json

      response = http(uri).request(request)
      raise "A Railway respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body.to_s)
      raise parsed["errors"].first["message"] if parsed["errors"].present?

      parsed
    end

    def http(uri)
      @http ||= Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.use_ssl = true
        client.open_timeout = REQUEST_TIMEOUT
        client.read_timeout = REQUEST_TIMEOUT
      end
    end
  end
end
