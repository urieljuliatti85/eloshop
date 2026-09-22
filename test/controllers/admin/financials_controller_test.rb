require "csv"
require "test_helper"

class Admin::FinancialsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to login" do
    get admin_financials_path

    assert_redirected_to new_session_path
  end

  test "redirects unauthenticated reconciliation refresh to login" do
    post admin_financials_reconciliation_path

    assert_redirected_to new_session_path
  end

  test "admin sees the Mercado Pago financial status" do
    sign_in_as(users(:one))

    get admin_financials_path

    assert_response :success
    assert_select "h1", text: "Financials"
    assert_select "a[aria-current='page']", text: "Financials", minimum: 1
    assert_select "h2", text: "Integração Mercado Pago"
    assert_select "h2", text: "Movimentação financeira"
    assert_select "h2", text: "Conciliação Mercado Pago"
    assert_select "h2", text: "Artesãos com pendências"
    assert_select "li", text: /Conectar a conta Mercado Pago/, minimum: 1
  end

  test "page derives financial totals and never exposes configured secrets" do
    seller_order = seller_orders(:one)
    seller_order.update!(status: "confirmed")
    payments(:one).update!(gateway: "mercado_pago", status: "paid")
    sign_in_as(users(:one))

    with_env(
      "PAYMENT_GATEWAY" => "mercado_pago",
      "MERCADO_PAGO_MARKETPLACE_APP_ID" => "app-id",
      "MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET" => "oauth-client-secret-value",
      "MERCADO_PAGO_MARKETPLACE_REDIRECT_URI" => "https://example.test/painel/mercado-pago/callback",
      "MERCADO_PAGO_WEBHOOK_SECRET" => "webhook-secret-value"
    ) do
      get admin_financials_path
    end

    assert_response :success
    assert_select ".admin-badge", text: "Operacional", minimum: 1
    assert_select ".admin-stat-value", text: "R$ 104,90"
    assert_select ".admin-stat-value", text: "R$ 13,49"
    assert_select ".admin-stat-value", text: "R$ 91,41"
    assert_not_includes response.body, "oauth-client-secret-value"
    assert_not_includes response.body, "webhook-secret-value"
  end

  test "page shows local sales while the official report is not configured" do
    payment = payments(:one)
    payment.update!(
      gateway: "mercado_pago",
      status: "paid",
      application_fee_cents: 1_349,
      processor_fee_cents: 315
    )
    sign_in_as(users(:one))

    with_env("MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN" => nil) do
      get admin_financials_path
    end

    assert_response :success
    assert_select "code", text: "MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN"
    assert_select "a", text: "Pedido ##{payment.order_id}"
    assert_select ".admin-badge", text: "Somente EloShop"
    assert_select "td", text: "R$ 104,90"
    assert_select "td", text: "R$ 13,49"
    assert_select "td", text: "R$ 3,15"
    assert_select "td", text: "R$ 88,26"
  end

  test "manual refresh fetches the official report and enriches the release date" do
    payment = payments(:one)
    payment.update!(gateway: "mercado_pago", status: "paid", external_id: "mp-payment-1")
    entry = Marketplace::MercadoPagoSalesReport::Entry.new(
      payment_id: payment.external_id,
      external_reference: payment.order_id.to_s,
      collector_id: "seller-1",
      collector_name: "EloShop",
      status: "approved",
      transaction_amount_cents: 10_490,
      marketplace_fee_cents: 1_349,
      mercado_pago_fee_cents: 315,
      net_received_amount_cents: 8_826,
      approved_at: Time.zone.parse("2026-09-20T12:00:00Z")
    )
    report = Marketplace::MercadoPagoSalesReport::Report.new(
      statement_id: "statement-1",
      generated_at: Time.current,
      fetched_at: Time.current,
      entries: [ entry ]
    )
    report_client = Object.new
    report_client.define_singleton_method(:configured?) { true }
    report_client.define_singleton_method(:refresh!) { report }
    gateway = Object.new
    gateway.define_singleton_method(:reconciliation_details) do |external_id:|
      raise "pagamento inesperado" unless external_id == "mp-payment-1"

      { processor_fee_cents: 315, money_release_date: Time.zone.parse("2026-09-25T12:00:00Z") }
    end
    sign_in_as(users(:one))

    with_constructor_stub(Marketplace::MercadoPagoSalesReport, report_client) do
      with_constructor_stub(Gateways::MercadoPago, gateway) do
        post admin_financials_reconciliation_path
      end
    end

    assert_redirected_to admin_financials_path
    assert_equal "2026-09-25T12:00:00Z",
      Rails.cache.read(Admin::FinancialsController::RELEASE_DATES_CACHE_KEY).fetch("mp-payment-1")
  end

  test "page labels a matching official sale and uses the report amounts" do
    payment = payments(:one)
    payment.update!(gateway: "mercado_pago", status: "paid", external_id: "mp-payment-1")
    Rails.cache.write(
      Marketplace::MercadoPagoSalesReport::CACHE_KEY,
      {
        "statement_id" => "statement-1",
        "generated_at" => "2026-09-20T12:00:00Z",
        "fetched_at" => "2026-09-20T12:05:00Z",
        "entries" => [
          {
            "payment_id" => payment.external_id,
            "external_reference" => payment.order_id.to_s,
            "collector_id" => "seller-1",
            "collector_name" => "EloShop",
            "status" => "approved",
            "transaction_amount_cents" => 10_490,
            "marketplace_fee_cents" => 1_349,
            "mercado_pago_fee_cents" => 315,
            "net_received_amount_cents" => 8_826,
            "approved_at" => "2026-09-20T12:00:00Z"
          }
        ]
      },
      expires_in: 1.hour
    )
    Rails.cache.write(
      Admin::FinancialsController::RELEASE_DATES_CACHE_KEY,
      { payment.external_id => "2026-09-25T12:00:00Z" },
      expires_in: 1.hour
    )
    sign_in_as(users(:one))

    with_env("MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN" => "production-token") do
      get admin_financials_path
    end

    assert_response :success
    assert_select ".admin-badge", text: "Mercado Pago"
    assert_select "td", text: "R$ 88,26"
    assert_includes response.body, "25/09/2026"
  end

  test "admin can filter reconciliation rows by period, seller and release status" do
    payment = payments(:one)
    payment.update!(gateway: "mercado_pago", status: "paid", external_id: "mp-payment-1")
    Rails.cache.write(
      Admin::FinancialsController::RELEASE_DATES_CACHE_KEY,
      { payment.external_id => "2026-09-25T12:00:00Z" },
      expires_in: 1.hour
    )
    sign_in_as(users(:one))

    get admin_financials_path, params: {
      seller_id: sellers(:approved).id,
      date_from: "2026-09-01",
      date_to: "2026-09-30",
      release_status: "released"
    }

    assert_response :success
    assert_select "td", text: sellers(:approved).name, minimum: 1
    assert_select "a", text: /Pedido ##{payment.order_id}/, minimum: 1
  end

  test "admin can export reconciliation rows as csv with current filters" do
    payment = payments(:one)
    payment.update!(gateway: "mercado_pago", status: "paid", external_id: "mp-payment-1")
    Rails.cache.write(
      Admin::FinancialsController::RELEASE_DATES_CACHE_KEY,
      { payment.external_id => "2026-09-25T12:00:00Z" },
      expires_in: 1.hour
    )
    sign_in_as(users(:one))

    get admin_financials_export_path, params: {
      seller_id: sellers(:approved).id,
      release_status: "released"
    }

    assert_response :success
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_includes rows.first, "Venda"
    assert_includes rows.first, "Data de liberação"
  end

  private

  def with_constructor_stub(klass, instance)
    original_constructor = klass.method(:new)
    klass.define_singleton_method(:new) { |*| instance }
    yield
  ensure
    klass.define_singleton_method(:new, original_constructor)
  end

  def with_env(values)
    original_values = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
