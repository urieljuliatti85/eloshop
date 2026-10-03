require "application_system_test_case"

# O painel do vendedor precisa ser utilizável no celular: as tabelas de
# produtos e pedidos tinham 5-6 colunas que não cabiam em 390px e, com
# overflow-hidden, deixavam a ação "Detalhes" fora de alcance. `resize_to`
# não emula viewport estreito de verdade (o Chrome tem uma largura mínima de
# janela e para em ~500px) — só o CDP define o viewport real.
class SellerPortalMobileTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 390

  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  # Sem isso, o override de viewport vaza para o próximo teste que reusar a
  # mesma sessão do Chrome dentro da suíte — outros testes de sistema (que
  # não pedem viewport nenhum) passaram a falhar por página "estreita".
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "reaches a product's details from the mobile card list without horizontal scroll" do
    user = users(:seller)
    sign_in_seller(user)
    product = products(:one)

    visit seller_products_path

    assert_no_horizontal_overflow
    click_link product.name

    assert_current_path seller_product_path(product)
  end

  test "reaches an order's details from the mobile card list without horizontal scroll" do
    user = users(:seller)
    sign_in_seller(user)

    visit seller_orders_path

    assert_no_horizontal_overflow
  end

  test "navigates the panel through the hamburger menu instead of a sideways-scrolling strip" do
    sign_in_seller(users(:seller))
    visit seller_root_path

    # "Ver a loja" fica visível no topo, sem abrir o menu.
    assert_link "Ver a loja", href: products_path

    # Fechado: nenhum link do painel ocupa o topo, e nada rola para o lado.
    assert_no_link "Novo produto"
    assert_no_horizontal_overflow

    click_button "Abrir menu do painel"
    assert_selector "button[aria-expanded='true']"
    %w[Visão\ geral Primeiros\ passos Produtos Pedidos Mensagens Avaliações Dados\ do\ Ateliê Novo\ produto].each do |label|
      assert_link label
    end
    assert_no_horizontal_overflow

    click_link "Novo produto"
    assert_current_path new_seller_product_path

    # Turbo troca a página: o menu volta fechado.
    assert_no_link "Pedidos"
    assert_selector "button[aria-expanded='false']"
  end

  test "closes the hamburger menu with Escape" do
    sign_in_seller(users(:seller))
    visit seller_root_path

    click_button "Abrir menu do painel"
    assert_link "Pedidos"
    find("body").send_keys(:escape)

    assert_no_link "Pedidos"
  end

  private

  def sign_in_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end

  def assert_no_horizontal_overflow
    scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
    assert_equal MOBILE_WIDTH, scroll_width, "a página estourou a largura do viewport"
  end
end
