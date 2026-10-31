require "application_system_test_case"

class SellerDashboardTest < ApplicationSystemTestCase
  setup do
    user = users(:seller)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end

  test "seller reaches the redesigned dashboard and its main shortcuts" do
    visit seller_root_path

    assert_selector "h1", text: "Visão geral"
    assert_field "Buscar no seu catálogo"
    assert_link "Novo produto", href: new_seller_product_path
    assert_selector "h2", text: "O que fazer agora"
    assert_link "Ver todos", href: seller_orders_path
  end

  # A prova de que não houve navegação: uma marca na `window` só sobrevive
  # enquanto a página não é recarregada.
  test "Primeiros passos are worked on inside the /painel, without leaving it" do
    sellers(:approved).update!(origin_zip_code: nil, origin_street: nil, origin_number: nil,
      origin_neighborhood: nil, origin_city: nil, origin_state: nil)
    visit seller_root_path
    assert_selector "#current-step-title", text: "Preencha o endereço do ateliê"
    page.execute_script("window.__samePage = true")

    within("turbo-frame#primeiros-passos") { click_link "Chave PIX" }

    assert_selector "#current-step-title", text: "Cadastre uma chave PIX no Mercado Pago"
    assert_current_path seller_root_path(etapa: "chave-pix")
    assert page.evaluate_script("window.__samePage")

    within("turbo-frame#primeiros-passos") { click_link "Endereço do ateliê" }
    assert_selector "#current-step-title", text: "Preencha o endereço do ateliê"

    # Valores sem disparar `input`: a busca de CEP e de rua chamaria a rede.
    page.execute_script(<<~JS)
      const values = { origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
        origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP" }
      for (const [field, value] of Object.entries(values)) document.querySelector(`[name="seller[${field}]"]`).value = value
    JS
    click_button "Salvar e continuar"

    assert_selector "#current-step-title", text: "Conecte sua conta do Mercado Pago"
    assert page.evaluate_script("window.__samePage")
    assert sellers(:approved).reload.origin_address_complete?
  end

  test "on mobile, a floating link brings the seller back to the page menu" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit seller_root_path
    assert_selector "nav[aria-label='Nesta página']"
    assert_no_link "Voltar ao topo"

    click_link "Últimos pedidos"

    assert_link "Voltar ao topo"
    click_link "Voltar ao topo"
    assert_no_link "Voltar ao topo"
    assert_selector "nav[aria-label='Nesta página']", visible: true
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "on mobile, the setup tabs open each step in the /painel" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit seller_products_path

    within("nav[aria-label='Primeiros passos']") { click_link "PIX" }

    assert_current_path seller_root_path(etapa: "chave-pix")
    assert_selector "#current-step-title", text: "Cadastre uma chave PIX no Mercado Pago"
    within("nav[aria-label='Primeiros passos']") { assert_selector "a[aria-current='page']", text: "Início" }
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "dashboard remains usable without horizontal page overflow on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)

    visit seller_root_path

    # No celular a navegação vive no hambúrguer, não numa faixa com rolagem lateral.
    click_button "Abrir menu do painel"
    assert_link "Novo produto", visible: true
    assert_equal page.evaluate_script("document.documentElement.clientWidth"),
      page.evaluate_script("document.documentElement.scrollWidth")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
