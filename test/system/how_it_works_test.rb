require "application_system_test_case"

# Os carrosséis da aba "Quem vende" (vantagens e etapas) só existem no
# celular e dependem do carousel_controller: só um teste de sistema prova que
# eles navegam.
class HowItWorksTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 390

  # A emulação de celular (CDP) continua valendo no teste seguinte se não
  # for desfeita.
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "on mobile, the seller steps are a carousel with buttons and dots" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende")

    assert_selector "[aria-label='Ir para o passo 1'][aria-selected='true']"

    click_button "Próximo passo"
    assert_selector "[aria-label='Ir para o passo 2'][aria-selected='true']"

    find("[aria-label='Ir para o passo 6']").click
    assert_selector "[aria-label='Ir para o passo 6'][aria-selected='true']"

    click_button "Passo anterior"
    assert_selector "[aria-label='Ir para o passo 5'][aria-selected='true']"

    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # Cliques seguidos, antes de a rolagem animada terminar: a posição tem de
  # seguir os cliques, não um slide do meio do caminho.
  test "on mobile, quick taps on next move one step each" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende")
    assert_selector "[aria-label='Ir para o passo 1'][aria-selected='true']"

    page.execute_script(<<~JS)
      const next = document.querySelector("[aria-label='Próximo passo']")
      next.click()
      setTimeout(() => next.click(), 60)
      setTimeout(() => next.click(), 120)
    JS

    assert_selector "[aria-label='Ir para o passo 4'][aria-selected='true']"
    sleep 1
    assert_selector "[aria-label='Ir para o passo 4'][aria-selected='true']"
  end

  test "on mobile, the seller benefits are a carousel too" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende")

    assert_selector "[aria-label='Ir para a vantagem 1'][aria-selected='true']"

    click_button "Próxima vantagem"
    assert_selector "[aria-label='Ir para a vantagem 2'][aria-selected='true']"

    find("[aria-label='Ir para a vantagem 4']").click
    assert_selector "[aria-label='Ir para a vantagem 4'][aria-selected='true']"
  end

  test "on desktop, the carousel controls stay hidden" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit how_it_works_path(aba: "vende")

    assert_no_button "Próxima vantagem"
    assert_no_button "Próximo passo"
  end

  # Abas aninhadas: o grupo de "Quem vende" troca sem mexer na aba de fora, e
  # a URL guarda os dois parâmetros.
  test "switching the seller group shows the distributor steps and keeps the outer tab" do
    visit how_it_works_path(aba: "vende")
    assert_text "Venda suas peças como o seu próprio negócio"

    click_button "Armarinho"

    assert_text "Venda insumos para quem faz à mão"
    assert_no_text "Venda suas peças como o seu próprio negócio"
    assert_selector "[role='tab'][data-tab-name='vende'][aria-selected='true']"
    assert_includes page.current_url, "aba=vende"
    assert_includes page.current_url, "grupo=armarinho"
  end

  test "on mobile, the distributor steps are a carousel too" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende", grupo: "armarinho")

    within("[data-tabs-target='panel'][data-tab-name='armarinho']") do
      assert_selector "[aria-label='Ir para o passo 1'][aria-selected='true']"
      click_button "Próximo passo"
      assert_selector "[aria-label='Ir para o passo 2'][aria-selected='true']"
      find("[aria-label='Ir para o passo 5']").click
      assert_selector "[aria-label='Ir para o passo 5'][aria-selected='true']"
    end
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end
end
