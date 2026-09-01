require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated access to admin login" do
    get admin_orders_path
    assert_redirected_to new_session_path
  end

  test "an authenticated admin can list orders" do
    sign_in_as(users(:one))

    get admin_orders_path

    assert_response :success
    assert_select "aside.admin-sidebar"
    assert_select "a[aria-current='page']", text: "Pedidos", minimum: 1
    assert_select ".admin-badge", text: "Pendente", minimum: 1
    assert_select "th", text: "Pagamento"
  end

  test "an authenticated admin can view any order" do
    sign_in_as(users(:one))

    get admin_order_path(orders(:one))

    assert_response :success
    assert_select "h2", text: "Itens do pedido"
    assert_select ".admin-section-label", text: "Resumo"
    assert_select "a", text: "Ver cliente"
  end
end
