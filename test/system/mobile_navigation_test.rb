require "application_system_test_case"

# Em telas estreitas os links de topo ficam escondidos (hidden md:flex) e o
# painel do hambúrguer é o único caminho do cabeçalho para a Loja, o Contato e
# o login. A janela é estreitada em cada teste porque o padrão da suíte
# (1400px) fica acima do breakpoint md e nunca exercitaria esse caminho.
#
# As asserções são escopadas ao <header>: o rodapé repete Início, Loja e
# Contato, e sem o escopo elas encontrariam sempre esses links.
class MobileNavigationTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 480

  setup do
    page.driver.browser.manage.window.resize_to(MOBILE_WIDTH, 900)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "the header menu opens and reaches the catalog" do
    visit new_contact_path

    within("header") { assert_no_link "Loja", visible: true }

    click_button "Abrir menu"
    within("header") { click_link "Loja" }

    assert_current_path products_path
  end

  test "the menu offers sign in to a visitor" do
    visit new_contact_path

    click_button "Abrir menu"
    within("header") { click_link "Entrar" }

    assert_current_path new_customer_session_path
  end

  test "the menu offers artisan sign-in to a visitor" do
    visit new_contact_path

    click_button "Abrir menu"
    within("header") { click_link "Entrar no Ateliê" }

    assert_current_path seller_login_path
  end

  test "the menu closes when Escape is pressed" do
    visit new_contact_path

    click_button "Abrir menu"
    within("header") { assert_link "Ateliês", visible: true }

    find("body").send_keys :escape

    within("header") { assert_no_link "Ateliês", visible: true }
  end
end
