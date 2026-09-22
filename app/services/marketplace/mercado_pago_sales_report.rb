require "bigdecimal"
require "csv"
require "json"
require "net/http"

module Marketplace
  # Leitura do relatório oficial de vendas do marketplace. A configuração e
  # a geração do relatório continuam no Mercado Pago; a EloShop apenas lista
  # os demonstrativos já gerados e baixa o mais recente, sem criar ou alterar
  # recursos financeiros no provedor.
  class MercadoPagoSalesReport
    class ConfigurationError < StandardError; end
    class RequestFailed < StandardError; end
    class ReportUnavailable < StandardError; end

    Entry = Data.define(
      :payment_id,
      :external_reference,
      :collector_id,
      :collector_name,
      :status,
      :transaction_amount_cents,
      :marketplace_fee_cents,
      :mercado_pago_fee_cents,
      :net_received_amount_cents,
      :approved_at
    )
    Report = Data.define(:statement_id, :generated_at, :fetched_at, :entries)

    API_HOST = "api.mercadopago.com"
    STATEMENTS_PATH = "/v1/reports/marketplace_sellers_sales/statements"
    CACHE_KEY = "admin/mercado_pago_sales_report/v1"
    CACHE_TTL = 24.hours
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30

    def initialize(access_token: ENV["MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN"], cache: Rails.cache)
      @access_token = access_token
      @cache = cache
    end

    def configured?
      @access_token.present?
    end

    def cached
      payload = @cache.read(CACHE_KEY)
      deserialize(payload) if payload.present?
    rescue KeyError, ArgumentError, TypeError
      nil
    end

    def refresh!
      require_configuration!

      statement = latest_statement!
      statement_id = statement.fetch("id") { statement.fetch("statement_id") }.to_s
      report = Report.new(
        statement_id: statement_id,
        generated_at: parse_time(statement["date_created"] || statement["created_at"] || statement["creation_date"]),
        fetched_at: Time.current,
        entries: parse_csv(download_statement(statement_id))
      )

      @cache.write(CACHE_KEY, serialize(report), expires_in: CACHE_TTL)
      report
    end

    private

    def require_configuration!
      return if configured?

      raise ConfigurationError, "token de produção do relatório Mercado Pago não configurado"
    end

    def latest_statement!
      payload = JSON.parse(request(STATEMENTS_PATH, accept: "application/json"))
      statements = if payload.is_a?(Array)
        payload
      elsif statement_id(payload).present?
        [ payload ]
      else
        payload["results"] || payload["statements"] || []
      end
      statements = Array(statements).select { |statement| statement.is_a?(Hash) && statement_id(statement).present? }
      statements = statements.select { |statement| statement["status"].blank? || statement["status"].to_s.downcase == "available" }
      raise ReportUnavailable, "nenhum relatório de vendas disponível no Mercado Pago" if statements.empty?

      statements.max_by do |statement|
        parse_time(statement["date_created"] || statement["created_at"] || statement["creation_date"]) || Time.at(0)
      end
    rescue JSON::ParserError
      raise RequestFailed, "Mercado Pago devolveu uma lista de relatórios ilegível"
    end

    def statement_id(statement)
      return unless statement.respond_to?(:[])

      statement["id"] || statement["statement_id"]
    end

    def download_statement(statement_id)
      escaped_id = URI.encode_www_form_component(statement_id)
      request("#{STATEMENTS_PATH}/#{escaped_id}/download?format=csv", accept: "text/csv")
    end

    def parse_csv(source)
      csv = source.to_s.delete_prefix("\uFEFF")
      CSV.parse(csv, headers: true, col_sep: ";").filter_map do |row|
        normalized = row.to_h.transform_keys { |key| key.to_s.delete_prefix("\uFEFF").strip.upcase }
        payment_id = normalized["PAYMENT"].to_s.presence
        external_reference = normalized["EXTERNAL_REFERENCE"].to_s.presence
        next if payment_id.blank? && external_reference.blank?

        Entry.new(
          payment_id: payment_id,
          external_reference: external_reference,
          collector_id: normalized["COLLECTOR"].to_s.presence,
          collector_name: normalized["COLLECTOR_NICKNAME"].to_s.presence,
          status: normalized["STATUS_DESCRIPTION"].to_s.presence,
          transaction_amount_cents: cents(normalized["TRANSACTION_AMOUNT"]),
          marketplace_fee_cents: cents(normalized["MARKETPLACE_FEE_AMOUNT"]),
          mercado_pago_fee_cents: cents(normalized["MERCADOPAGO_FEE_AMOUNT"]),
          net_received_amount_cents: cents(normalized["NET_RECEIVED_AMOUNT"]),
          approved_at: parse_time(normalized["DATE_APPROVED"] || normalized["DATE_CREATED"])
        )
      end
    rescue CSV::MalformedCSVError, ArgumentError
      raise RequestFailed, "Mercado Pago devolveu um relatório de vendas ilegível"
    end

    def cents(value)
      raw = value.to_s.strip
      return if raw.blank?

      normalized = if raw.include?(",") && raw.include?(".")
        raw.delete(",")
      else
        raw.tr(",", ".")
      end
      (BigDecimal(normalized) * 100).round.to_i
    rescue ArgumentError
      nil
    end

    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError, TypeError
      nil
    end

    def request(path, accept:)
      request = Net::HTTP::Get.new(path)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Accept"] = accept
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestFailed, "Mercado Pago respondeu #{response.code} ao consultar o relatório de vendas"
      end

      response.body.to_s
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise RequestFailed, "Não foi possível consultar o relatório de vendas do Mercado Pago"
    end

    def serialize(report)
      {
        "statement_id" => report.statement_id,
        "generated_at" => report.generated_at&.iso8601,
        "fetched_at" => report.fetched_at.iso8601,
        "entries" => report.entries.map do |entry|
          entry.to_h.transform_keys(&:to_s).tap do |attributes|
            attributes["approved_at"] = entry.approved_at&.iso8601
          end
        end
      }
    end

    def deserialize(payload)
      Report.new(
        statement_id: payload.fetch("statement_id"),
        generated_at: parse_time(payload["generated_at"]),
        fetched_at: parse_time(payload.fetch("fetched_at")),
        entries: payload.fetch("entries").map do |attributes|
          values = attributes.symbolize_keys
          values[:approved_at] = parse_time(values[:approved_at])
          Entry.new(**values)
        end
      )
    end

    def http
      @http ||= Net::HTTP.new(API_HOST, 443).tap do |client|
        client.use_ssl = true
        client.open_timeout = OPEN_TIMEOUT
        client.read_timeout = READ_TIMEOUT
      end
    end
  end
end
