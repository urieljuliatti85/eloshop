require "test_helper"

module Marketplace
  class MercadoPagoSalesReportTest < ActiveSupport::TestCase
    ACCESS_TOKEN = "APP_USR-production-token"

    setup do
      @service = MercadoPagoSalesReport.new(access_token: ACCESS_TOKEN)
    end

    test "is not configured without the production access token" do
      service = MercadoPagoSalesReport.new(access_token: nil)

      assert_not service.configured?
      assert_raises(MercadoPagoSalesReport::ConfigurationError) { service.refresh! }
    end

    test "downloads and parses the latest official marketplace sales report" do
      requests = stub_report_requests(
        statements: [
          { "id" => "older", "date_created" => "2026-09-19T10:00:00Z" },
          { "id" => "latest", "date_created" => "2026-09-20T10:00:00Z", "status" => "available" },
          { "id" => "pending", "date_created" => "2026-09-21T10:00:00Z", "status" => "processing" }
        ],
        csv: <<~CSV
          COLLECTOR;COLLECTOR_NICKNAME;PAYMENT;EXTERNAL_REFERENCE;STATUS_DESCRIPTION;TRANSACTION_AMOUNT;DATE_APPROVED;MARKETPLACE_FEE_AMOUNT;MERCADOPAGO_FEE_AMOUNT;NET_RECEIVED_AMOUNT
          143360137;Ateliê do Mercado Pago;987654;43;approved;120.00;2026-09-20T09:30:00Z;15.00;3.59;101.41
        CSV
      )

      report = @service.refresh!
      entry = report.entries.sole

      assert_equal "latest", report.statement_id
      assert_equal "987654", entry.payment_id
      assert_equal "43", entry.external_reference
      assert_equal "Ateliê do Mercado Pago", entry.collector_name
      assert_equal 12_000, entry.transaction_amount_cents
      assert_equal 1_500, entry.marketplace_fee_cents
      assert_equal 359, entry.mercado_pago_fee_cents
      assert_equal 10_141, entry.net_received_amount_cents
      assert_equal MercadoPagoSalesReport::STATEMENTS_PATH, requests.first.path
      assert_equal "Bearer #{ACCESS_TOKEN}", requests.first["Authorization"]
      assert_equal "#{MercadoPagoSalesReport::STATEMENTS_PATH}/latest/download?format=csv", requests.last.path
    end

    test "accepts the singular statement response documented by Mercado Pago" do
      stub_report_requests(
        statements: { "id" => "only", "date_created" => "2026-09-20T10:00:00Z", "status" => "available" },
        csv: "PAYMENT;TRANSACTION_AMOUNT\n123;10.00\n"
      )

      assert_equal "only", @service.refresh!.statement_id
    end

    test "caches parsed data without storing the access token" do
      stub_report_requests(
        statements: { "id" => "statement-1", "date_created" => "2026-09-20T10:00:00Z" },
        csv: "PAYMENT;TRANSACTION_AMOUNT\n123;10.00\n"
      )

      original = @service.refresh!
      cached = @service.cached

      assert_equal original.statement_id, cached.statement_id
      assert_equal 1_000, cached.entries.sole.transaction_amount_cents
      assert_not_includes Rails.cache.read(MercadoPagoSalesReport::CACHE_KEY).inspect, ACCESS_TOKEN
    end

    test "does not expose the provider response body in an error" do
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |_request|
        Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap do |response|
          response.define_singleton_method(:body) { '{"access_token":"leaked"}' }
        end
      end
      @service.instance_variable_set(:@http, fake_http)

      error = assert_raises(MercadoPagoSalesReport::RequestFailed) { @service.refresh! }
      assert_not_includes error.message, "leaked"
    end

    private

    def stub_report_requests(statements:, csv:)
      requests = []
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        requests << request
        body = request.path.include?("/download") ? csv : statements.to_json
        Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
          response.define_singleton_method(:body) { body }
        end
      end
      @service.instance_variable_set(:@http, fake_http)
      requests
    end
  end
end
