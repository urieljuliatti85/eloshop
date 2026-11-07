require "application_system_test_case"

class HomeCarouselTest < ApplicationSystemTestCase
  test "the visitor reaches the artisan banner through the carousel controls" do
    visit root_path

    # Os dois banners estão no HTML desde o começo — o carrossel move a faixa,
    # não troca o conteúdo.
    assert_text "Encontre peças únicas. Conheça quem as faz."
    assert_text "Venda suas peças mais criativas através do nosso Ateliê"

    # Os controles só existem com JavaScript; sem ele a rolagem da faixa dá
    # conta e um botão inerte seria pior que nenhum.
    assert_selector "button[aria-label='Próximo banner']"

    # O banner do artesão é o terceiro (o primeiro é o do Instagram).
    click_button "Próximo banner"
    click_button "Próximo banner"
    # Dentro do carrossel: o mesmo rótulo existe no topo, no menu da direita.
    within("[aria-roledescription='carrossel']") { click_link "Seja um artesão" }

    assert_current_path new_seller_registration_path
  end

  # O quarto banner é o do distribuidor de insumos (ADR 007).
  test "the visitor reaches the distributor banner, which leads to its how-it-works group" do
    visit root_path
    assert_text "Venda insumos para quem faz à mão"

    3.times { click_button "Próximo banner" }
    assert_selector "[aria-label='Ir para o banner 4'][aria-selected='true']"
    within("[aria-roledescription='carrossel'] [aria-label='4 de 4']") { click_link "Cadastre sua distribuidora" }

    assert_current_path new_distributor_registration_path
  end

  test "the carousel opens with the EloShop Instagram banner" do
    visit root_path

    assert_selector "[aria-label='Ir para o banner 1'][aria-selected='true']"
    within("[aria-roledescription='carrossel'] [aria-label='1 de 4']") do
      assert_link "Seguir @eloshop__ no Instagram (abre em nova aba)", href: "https://www.instagram.com/eloshop__"
    end
  end

  test "on mobile, the Instagram icon sits in the top bar without widening the page" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    customer = Customer.create!(name: "Cliente Topo", email: "cliente-topo@example.com", password: "password123")
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
    assert_no_current_path new_customer_session_path

    visit root_path

    within("header") do
      assert_link "Instagram da EloShop (abre em nova aba)"
      assert_link "Notificações"
    end
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
