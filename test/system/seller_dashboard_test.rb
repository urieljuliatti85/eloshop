require "application_system_test_case"

class SellerDashboardTest < ApplicationSystemTestCase
  setup do
    user = users(:seller)
    visit new_session_path
    fill_in "Informe seu e-mail", with: user.email_address
    fill_in "Informe sua senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end

  test "seller reaches the redesigned dashboard and its main shortcuts" do
    visit seller_root_path

    assert_selector "h1", text: "Crie, publique e acompanhe cada venda."
    assert_field "Buscar no seu catálogo"
    assert_link "Adicionar nova peça", href: new_seller_product_path
    assert_link "Acompanhar pedidos", href: seller_orders_path
  end

  test "dashboard remains usable without horizontal page overflow on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)

    visit seller_root_path

    assert_link "Novo produto", visible: true
    assert_equal page.evaluate_script("document.documentElement.clientWidth"),
      page.evaluate_script("document.documentElement.scrollWidth")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
