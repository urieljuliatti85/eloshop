require "application_system_test_case"

# "Venda na EloShop" no topo do desktop (ADR 007): as portas do ateliê e do
# distribuidor num item só, com o mesmo comportamento do menu de conta.
class SellMenuTest < ApplicationSystemTestCase
  test "opens the seller doors, closes on Esc and leads to the distributor door" do
    page.driver.browser.manage.window.resize_to(1280, 800)
    visit root_path

    click_button "Venda na EloShop"
    within("#sell-menu") do
      assert_link "Entrar no Ateliê"
      assert_link "Cadastre seu Ateliê"
      assert_link "Entrar no Painel do Distribuidor"
      assert_link "Cadastre sua Distribuidora"
    end

    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "#sell-menu", visible: true

    click_button "Venda na EloShop"
    within("#sell-menu") { click_link "Entrar no Painel do Distribuidor" }
    assert_current_path distributor_login_path
    assert_no_selector "#sell-menu", visible: true
  end

  # O topo de pílulas começa em 1024px (abaixo dele, hambúrguer e abas de
  # baixo) e precisa caber numa linha, sem rolagem lateral, também com
  # Distribuidores no menu.
  test "the desktop menu fits on one line from 1024px, and below it the mobile menu takes over" do
    page.driver.browser.manage.window.resize_to(900, 800)
    visit root_path
    assert_selector "nav.storefront-tabs", visible: true
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), "900px"

    [ 1024, 1100, 1280, 1440 ].each do |width|
      page.driver.browser.manage.window.resize_to(width, 800)
      visit root_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), "#{width}px"
      assert_operator page.evaluate_script("document.querySelector('header nav').getBoundingClientRect().height"), :<, 50, "#{width}px"
    end
  end

  test "on mobile, the bottom bar opens the seller doors and closes on Esc" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 360, height: 760, deviceScaleFactor: 1, mobile: true)
    visit root_path

    within("nav.storefront-tabs") { click_button "Venda na EloShop" }
    within("#sell-sheet") { assert_link "Entrar no Painel do Distribuidor" }
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")

    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "#sell-sheet", visible: true

    within("nav.storefront-tabs") { click_button "Venda na EloShop" }
    within("#sell-sheet") { click_link "Cadastre seu Ateliê" }
    assert_current_path new_seller_registration_path
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
