require "test_helper"

class Admin::FinancialsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to login" do
    get admin_financials_path

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

  private

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
